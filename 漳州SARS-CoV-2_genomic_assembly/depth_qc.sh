#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SAMPLE_LIST="/home/mzy/working/20260730_20260723_12sample_XG/samples.txt"

# 按你的实际 BED 位置修改这里
PRIMER_BED="/home/mzy/working/20260730_20260723_12sample_XG/SARS_CoV_V5.4.2_new.bed"

RAW_ROOT="/home/mzy/working/20260730_20260723_12sample_XG/02.minimap2"
TRIM_ROOT="/home/mzy/working/20260730_20260723_12sample_XG/03.ivar_trim"
OUT_ROOT="/home/mzy/working/20260730_20260723_12sample_XG/04.depth_qc"
LOG_ROOT="/home/mzy/working/20260730_20260723_12sample_XG/04.depth_qc"

SAMTOOLS_BIN="${SAMTOOLS_BIN:-/home/mzy/.conda/envs/covid_amplicon/bin/samtools}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

mkdir -p "${OUT_ROOT}" "${LOG_ROOT}"

if [[ ! -s "${SAMPLE_LIST}" ]]; then
  echo "[ERROR] sample list not found: ${SAMPLE_LIST}" >&2
  exit 1
fi

if [[ ! -s "${PRIMER_BED}" ]]; then
  echo "[ERROR] primer BED not found: ${PRIMER_BED}" >&2
  exit 1
fi

if [[ ! -x "${SAMTOOLS_BIN}" ]]; then
  echo "[ERROR] samtools not executable: ${SAMTOOLS_BIN}" >&2
  exit 1
fi

AMP_BED="${OUT_ROOT}/amplicons.from_primers.bed"
AMP_DEBUG="${OUT_ROOT}/amplicons.from_primers.debug.tsv"

# 根据 primer BED 自动生成 amplicon BED。
# 同一个扩增子如果有多个普通/替代/patch primer，用所有 LEFT 的最小 start 和所有 RIGHT 的最大 end 定义范围。
"${PYTHON_BIN}" - "${PRIMER_BED}" "${AMP_BED}" "${AMP_DEBUG}" <<'PY'
import re
import sys
from collections import defaultdict

primer_bed, amp_bed, debug_tsv = sys.argv[1:4]

amps = defaultdict(lambda: {
    "chrom": None,
    "left_starts": [],
    "right_ends": [],
    "pools": set(),
    "left_names": [],
    "right_names": [],
})

SIDE_RE = re.compile(r"(?:^|[_-])(?P<side>LEFT|RIGHT|FWD|REV|F|R)(?:[_-]|$)", re.I)


def primer_side(name):
    m = SIDE_RE.search(name)
    if not m:
        raise ValueError(f"cannot parse primer side from primer name: {name}")
    side = m.group("side").upper()
    if side in {"LEFT", "FWD", "F"}:
        return "LEFT"
    return "RIGHT"


def amp_id_from_name(name):
    # Patch style: amplicon_67_patch1_cand1_LEFT -> 67.
    m = re.search(r"(?:^|[_-])amplicon[_-](\d+)(?:[_-]|$)", name, re.I)
    if m:
        return int(m.group(1))

    # ARTIC style: 2_67_LEFT_1 -> 67, SARS_CoV_v5.4.2_10_RIGHT -> 10.
    m = re.search(r"(?:^|[_-])(?:[A-Za-z]+[_-])?(\d+)[_-](?:LEFT|RIGHT|FWD|REV|F|R)(?:[_-]|$)", name, re.I)
    if m:
        return int(m.group(1))

    raise ValueError(f"cannot parse amplicon id from primer name: {name}")

with open(primer_bed, "r", encoding="utf-8") as f:
    for line in f:
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.rstrip("\n").split("\t")
        if len(cols) < 4:
            continue

        chrom = cols[0]
        start = int(cols[1])
        end = int(cols[2])
        name = cols[3]
        pool = cols[4] if len(cols) >= 5 else "NA"

        amp_id = amp_id_from_name(name)
        side = primer_side(name)

        amps[amp_id]["chrom"] = chrom
        amps[amp_id]["pools"].add(pool)

        if side == "LEFT":
            amps[amp_id]["left_starts"].append(start)
            amps[amp_id]["left_names"].append(name)
        else:
            amps[amp_id]["right_ends"].append(end)
            amps[amp_id]["right_names"].append(name)

with open(amp_bed, "w", encoding="utf-8") as out:
    for amp_id in sorted(amps):
        item = amps[amp_id]
        if not item["left_starts"] or not item["right_ends"]:
            print(f"[WARN] amplicon {amp_id} missing LEFT or RIGHT primer, skipped", file=sys.stderr)
            continue

        chrom = item["chrom"]
        start = min(item["left_starts"])
        end = max(item["right_ends"])
        pools = ",".join(sorted(item["pools"]))

        out.write(f"{chrom}\t{start}\t{end}\tamplicon_{amp_id}\t{pools}\n")

with open(debug_tsv, "w", encoding="utf-8") as out:
    out.write("amplicon\tpool\tleft_count\tright_count\tleft_primers\tright_primers\n")
    for amp_id in sorted(amps):
        item = amps[amp_id]
        pools = ",".join(sorted(item["pools"]))
        out.write(
            "\t".join([
                f"amplicon_{amp_id}",
                pools,
                str(len(item["left_names"])),
                str(len(item["right_names"])),
                ",".join(item["left_names"]),
                ",".join(item["right_names"]),
            ]) + "\n"
        )
PY

ALL_SUMMARY="${OUT_ROOT}/all_samples.amplicon_depth.tsv"
LOW_SUMMARY="${OUT_ROOT}/low_coverage_amplicons.tsv"

echo -e "sample\tamplicon\tpool\tstart\tend\tmean_depth\tmedian_depth\tmin_depth\tpct_ge_10x\tpct_ge_20x\tpct_ge_100x\tstatus" > "${ALL_SUMMARY}"

while IFS= read -r sample || [[ -n "${sample}" ]]; do
  [[ -z "${sample}" || "${sample}" =~ ^# ]] && continue

  echo "[INFO] processing ${sample}"

  outdir="${OUT_ROOT}/${sample}"
  mkdir -p "${outdir}"

  raw_bam="${RAW_ROOT}/${sample}/${sample}.raw.sorted.bam"
  trim_bam="${TRIM_ROOT}/${sample}/${sample}.trimmed.sorted.bam"

  raw_depth="${outdir}/${sample}.raw.depth.tsv.gz"
  trim_depth="${outdir}/${sample}.trimmed.depth.tsv.gz"
  sample_summary="${outdir}/${sample}.amplicon_depth.tsv"

  if [[ ! -s "${raw_bam}" ]]; then
    echo "[ERROR] raw BAM not found: ${raw_bam}" >&2
    exit 1
  fi

  if [[ ! -s "${trim_bam}" ]]; then
    echo "[ERROR] trimmed BAM not found: ${trim_bam}" >&2
    exit 1
  fi

  # quickcheck 用来提前发现 BAM 截断或索引异常。
  "${SAMTOOLS_BIN}" quickcheck -v "${raw_bam}" "${trim_bam}"

  # -aa 保留 0 覆盖位点，否则低覆盖区域会被低估。
  "${SAMTOOLS_BIN}" depth -aa "${raw_bam}" | gzip -c > "${raw_depth}"
  "${SAMTOOLS_BIN}" depth -aa "${trim_bam}" | gzip -c > "${trim_depth}"

  "${PYTHON_BIN}" - "${sample}" "${trim_depth}" "${AMP_BED}" "${sample_summary}" <<'PY'
import gzip
import statistics
import sys

sample, depth_gz, amp_bed, out_tsv = sys.argv[1:5]

depth = {}

with gzip.open(depth_gz, "rt") as f:
    for line in f:
        chrom, pos, dep = line.rstrip("\n").split("\t")[:3]
        depth[(chrom, int(pos))] = int(dep)

rows = []

with open(amp_bed, "r", encoding="utf-8") as f:
    for line in f:
        if not line.strip() or line.startswith("#"):
            continue

        chrom, start, end, amp, pool = line.rstrip("\n").split("\t")[:5]
        start = int(start)
        end = int(end)

        # BED 是 0-based half-open；samtools depth 是 1-based。
        values = [depth.get((chrom, p), 0) for p in range(start + 1, end + 1)]

        if values:
            mean_depth = sum(values) / len(values)
            median_depth = statistics.median(values)
            min_depth = min(values)
            pct_ge_10x = sum(v >= 10 for v in values) * 100 / len(values)
            pct_ge_20x = sum(v >= 20 for v in values) * 100 / len(values)
            pct_ge_100x = sum(v >= 100 for v in values) * 100 / len(values)
        else:
            mean_depth = median_depth = min_depth = pct_ge_10x = pct_ge_20x = pct_ge_100x = 0

        if median_depth < 10:
            status = "LOW"
        elif median_depth < 20:
            status = "WARNING"
        else:
            status = "PASS"

        rows.append([
            sample,
            amp,
            pool,
            str(start + 1),
            str(end),
            f"{mean_depth:.2f}",
            f"{median_depth:.2f}",
            str(min_depth),
            f"{pct_ge_10x:.2f}",
            f"{pct_ge_20x:.2f}",
            f"{pct_ge_100x:.2f}",
            status,
        ])

with open(out_tsv, "w", encoding="utf-8") as out:
    out.write("sample\tamplicon\tpool\tstart\tend\tmean_depth\tmedian_depth\tmin_depth\tpct_ge_10x\tpct_ge_20x\tpct_ge_100x\tstatus\n")
    for row in rows:
        out.write("\t".join(row) + "\n")
PY

  tail -n +2 "${sample_summary}" >> "${ALL_SUMMARY}"

  echo "[INFO] finished ${sample}"
done < "${SAMPLE_LIST}"

awk 'NR == 1 || $12 == "LOW" || $12 == "WARNING"' "${ALL_SUMMARY}" > "${LOW_SUMMARY}"

echo "[INFO] amplicon summary: ${ALL_SUMMARY}"
echo "[INFO] low/warning amplicons: ${LOW_SUMMARY}"
echo "喵喵喵"
