#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SAMPLE_LIST="/home/mzy/working/20260810_20260716_Cov2/samples.txt"

CONS_ROOT="/home/mzy/working/20260810_20260716_Cov2/06.consensus"
DEPTH_ROOT="/home/mzy/working/20260810_20260716_Cov2/04.depth_qc"
PRIMER_QC_ROOT="/home/mzy/working/20260810_20260716_Cov2/05.primer_site_qc"
OUT_ROOT="/home/mzy/working/20260810_20260716_Cov2/07.final_qc"

PYTHON_BIN="${PYTHON_BIN:-python3}"

mkdir -p "${OUT_ROOT}"

if [[ ! -s "${SAMPLE_LIST}" ]]; then
  echo "[ERROR] sample list not found: ${SAMPLE_LIST}" >&2
  exit 1
fi

if [[ ! -s "${DEPTH_ROOT}/all_samples.amplicon_depth.tsv" ]]; then
  echo "[ERROR] amplicon depth table not found: ${DEPTH_ROOT}/all_samples.amplicon_depth.tsv" >&2
  exit 1
fi

"${PYTHON_BIN}" - \
  "${SAMPLE_LIST}" \
  "${CONS_ROOT}" \
  "${DEPTH_ROOT}" \
  "${PRIMER_QC_ROOT}" \
  "${OUT_ROOT}" <<'PY'
import gzip
import os
import statistics
import sys
from collections import defaultdict

sample_list, cons_root, depth_root, primer_qc_root, out_root = sys.argv[1:6]

def read_samples(path):
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if s and not s.startswith("#"):
                samples.append(s)
    return samples

def read_fasta_seq(path):
    seqs = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith(">"):
                continue
            seqs.append(line.strip().upper())
    return "".join(seqs)

def median_or_zero(values):
    return statistics.median(values) if values else 0

samples = read_samples(sample_list)

amp_depth_tsv = os.path.join(depth_root, "all_samples.amplicon_depth.tsv")
primer_qc_tsv = os.path.join(primer_qc_root, "all_samples.primer_site_qc.tsv")
variant_tsv = os.path.join(cons_root, "all_samples.variants.tsv")

amp_rows = defaultdict(list)

with open(amp_depth_tsv, "r", encoding="utf-8") as f:
    header = f.readline().rstrip("\n").split("\t")
    idx = {k: i for i, k in enumerate(header)}

    for line in f:
        cols = line.rstrip("\n").split("\t")
        sample = cols[idx["sample"]]
        amp_rows[sample].append({
            "amplicon": cols[idx["amplicon"]],
            "pool": cols[idx["pool"]],
            "mean_depth": float(cols[idx["mean_depth"]]),
            "median_depth": float(cols[idx["median_depth"]]),
            "min_depth": float(cols[idx["min_depth"]]),
            "pct_ge_10x": float(cols[idx["pct_ge_10x"]]),
            "pct_ge_20x": float(cols[idx["pct_ge_20x"]]),
            "pct_ge_100x": float(cols[idx["pct_ge_100x"]]),
            "status": cols[idx["status"]],
        })

primer_flags = defaultdict(lambda: defaultdict(int))
primer_problem_amps = defaultdict(set)

if os.path.exists(primer_qc_tsv) and os.path.getsize(primer_qc_tsv) > 0:
    with open(primer_qc_tsv, "r", encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        idx = {k: i for i, k in enumerate(header)}

        for line in f:
            cols = line.rstrip("\n").split("\t")
            sample = cols[idx["sample"]]
            amp = cols[idx["amplicon"]]
            flag = cols[idx["flag"]]

            if flag != "PASS":
                primer_flags[sample][flag] += 1
                primer_problem_amps[sample].add(amp)

variant_count = defaultdict(int)

if os.path.exists(variant_tsv) and os.path.getsize(variant_tsv) > 0:
    with open(variant_tsv, "r", encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        idx_sample = 0

        for line in f:
            if line.strip():
                cols = line.rstrip("\n").split("\t")
                variant_count[cols[idx_sample]] += 1

final_tsv = os.path.join(out_root, "all_samples.final_qc.tsv")
problem_tsv = os.path.join(out_root, "all_samples.amplicon_problem_summary.tsv")

with open(final_tsv, "w", encoding="utf-8") as out:
    out.write(
        "sample\tgenome_length\tcalled_bases\tN_count\tN_pct\t"
        "genome_mean_depth\tgenome_median_depth\tgenome_min_depth\tgenome_pct_ge_10x\tgenome_pct_ge_20x\t"
        "amplicon_LOW_count\tamplicon_WARNING_count\tamplicon_high_median_ge_100x_count\t"
        "amplicon_median_depth_ratio\tpossible_primer_binding_mutation_sites\tlow_depth_primer_sites\t"
        "variant_count\tqc_status\tproblem_amplicons\n"
    )

    for sample in samples:
        cons_fa = os.path.join(cons_root, sample, f"{sample}.consensus.fa")
        depth_gz = os.path.join(depth_root, sample, f"{sample}.trimmed.depth.tsv.gz")

        if not os.path.exists(cons_fa):
            raise SystemExit(f"[ERROR] consensus fasta not found: {cons_fa}")

        if not os.path.exists(depth_gz):
            raise SystemExit(f"[ERROR] trimmed depth file not found: {depth_gz}")

        seq = read_fasta_seq(cons_fa)
        genome_len = len(seq)
        n_count = seq.count("N")
        called_bases = sum(seq.count(x) for x in "ACGT")
        n_pct = n_count * 100 / genome_len if genome_len else 0

        depths = []
        with gzip.open(depth_gz, "rt") as f:
            for line in f:
                cols = line.rstrip("\n").split("\t")
                if len(cols) >= 3:
                    depths.append(int(cols[2]))

        genome_mean_depth = sum(depths) / len(depths) if depths else 0
        genome_median_depth = median_or_zero(depths)
        genome_min_depth = min(depths) if depths else 0
        genome_pct_ge_10x = sum(d >= 10 for d in depths) * 100 / len(depths) if depths else 0
        genome_pct_ge_20x = sum(d >= 20 for d in depths) * 100 / len(depths) if depths else 0

        rows = amp_rows.get(sample, [])
        low_count = sum(r["status"] == "LOW" for r in rows)
        warning_count = sum(r["status"] == "WARNING" for r in rows)
        high_count = sum(r["median_depth"] >= 100 for r in rows)

        amp_medians = [r["median_depth"] for r in rows if r["median_depth"] > 0]
        sample_amp_median = median_or_zero(amp_medians)
        max_amp_median = max(amp_medians) if amp_medians else 0
        amp_ratio = max_amp_median / sample_amp_median if sample_amp_median else 0

        primer_mut_sites = primer_flags[sample].get("POSSIBLE_PRIMER_BINDING_MUTATION", 0)
        low_primer_sites = primer_flags[sample].get("LOW_DEPTH_AT_PRIMER_SITE", 0)

        problem_amps = sorted({
            r["amplicon"] for r in rows if r["status"] in {"LOW", "WARNING"}
        } | primer_problem_amps[sample])

        # 简单分级：REVIEW 不等于失败，只是需要人工重点看。
        if n_pct <= 1 and genome_pct_ge_10x >= 95 and low_count == 0 and primer_mut_sites == 0:
            qc_status = "PASS"
        elif n_pct <= 5 and genome_pct_ge_10x >= 90 and low_count <= 2:
            qc_status = "WARNING"
        else:
            qc_status = "REVIEW"

        out.write(
            f"{sample}\t{genome_len}\t{called_bases}\t{n_count}\t{n_pct:.2f}\t"
            f"{genome_mean_depth:.2f}\t{genome_median_depth:.2f}\t{genome_min_depth}\t"
            f"{genome_pct_ge_10x:.2f}\t{genome_pct_ge_20x:.2f}\t"
            f"{low_count}\t{warning_count}\t{high_count}\t{amp_ratio:.2f}\t"
            f"{primer_mut_sites}\t{low_primer_sites}\t{variant_count[sample]}\t"
            f"{qc_status}\t{','.join(problem_amps) if problem_amps else 'NA'}\n"
        )

with open(problem_tsv, "w", encoding="utf-8") as out:
    out.write(
        "sample\tamplicon\tpool\tmedian_depth\tmean_depth\tpct_ge_10x\tpct_ge_20x\tpct_ge_100x\tstatus\tnote\n"
    )

    for sample in samples:
        for r in amp_rows.get(sample, []):
            notes = []

            if r["status"] in {"LOW", "WARNING"}:
                notes.append("low_or_warning_depth")

            if r["median_depth"] >= 100:
                notes.append("median_depth_ge_100x")

            if r["amplicon"] in primer_problem_amps[sample]:
                notes.append("primer_site_problem")

            if notes:
                out.write(
                    f"{sample}\t{r['amplicon']}\t{r['pool']}\t"
                    f"{r['median_depth']:.2f}\t{r['mean_depth']:.2f}\t"
                    f"{r['pct_ge_10x']:.2f}\t{r['pct_ge_20x']:.2f}\t{r['pct_ge_100x']:.2f}\t"
                    f"{r['status']}\t{';'.join(notes)}\n"
                )

print(f"[INFO] final QC table: {final_tsv}")
print(f"[INFO] amplicon problem table: {problem_tsv}")
PY

