#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SAMPLE_LIST="/home/mzy/working/20260812_SARS_Cov/samples.txt"

REF_FA="/home/mzy/reference/MN908947.3/MN908947.3.fa"
REF_MMI="/home/mzy/reference/MN908947.3/MN908947_3.mmi"

IN_ROOT="/home/mzy/working/20260812_SARS_Cov/01.artic_guppyplex"
OUT_ROOT="/home/mzy/working/20260812_SARS_Cov/02.minimap2"
LOG_ROOT="/home/mzy/working/20260812_SARS_Cov/logs/02.minimap2"

MIN_LEN="${MIN_LEN:-300}"
THREADS="${THREADS:-8}"

# 直接调用各环境中的程序，避免在管道中反复启动 conda
CONDA_ROOT="${CONDA_ROOT:-/home/user/miniconda3}"
MINIMAP2_BIN="${MINIMAP2_BIN:-${CONDA_ROOT}/envs/minimap2_env/bin/minimap2}"
SAMTOOLS_BIN="${SAMTOOLS_BIN:-${CONDA_ROOT}/envs/samtools_env/bin/samtools}"

mkdir -p "${OUT_ROOT}" "${LOG_ROOT}"

# 检查输入和软件
if [[ ! -s "${SAMPLE_LIST}" ]]; then
    echo "[ERROR] sample list not found or empty: ${SAMPLE_LIST}" >&2
    exit 1
fi

if [[ ! -s "${REF_FA}" ]]; then
    echo "[ERROR] reference FASTA not found: ${REF_FA}" >&2
    exit 1
fi

if [[ ! -x "${MINIMAP2_BIN}" ]]; then
    echo "[ERROR] minimap2 not executable: ${MINIMAP2_BIN}" >&2
    echo "[INFO] 请运行: find ~/miniconda3 -type f -path '*/bin/minimap2'" >&2
    exit 1
fi

if [[ ! -x "${SAMTOOLS_BIN}" ]]; then
    echo "[ERROR] samtools not executable: ${SAMTOOLS_BIN}" >&2
    echo "[INFO] 请运行: find ~/miniconda3 -type f -path '*/bin/samtools'" >&2
    exit 1
fi

echo "[INFO] minimap2: ${MINIMAP2_BIN}"
echo "[INFO] samtools: ${SAMTOOLS_BIN}"

# 建立参考基因组的 samtools 索引
if [[ ! -s "${REF_FA}.fai" ]]; then
    echo "[INFO] building FASTA index"
    "${SAMTOOLS_BIN}" faidx "${REF_FA}"
fi

# 建立 minimap2 索引
if [[ ! -s "${REF_MMI}" ]]; then
    echo "[INFO] building minimap2 index"
    "${MINIMAP2_BIN}" -d "${REF_MMI}" "${REF_FA}"
fi

while IFS= read -r sample || [[ -n "${sample}" ]]; do
    # 兼容 Windows 格式的 samples.txt
    sample="${sample%$'\r'}"
    [[ -z "${sample}" || "${sample}" =~ ^# ]] && continue

    fq="${IN_ROOT}/${sample}/${sample}.artic_guppyplex.min${MIN_LEN}.fastq.gz"
    outdir="${OUT_ROOT}/${sample}"
    bam="${outdir}/${sample}.raw.sorted.bam"
    tmp_bam="${outdir}/${sample}.raw.sorted.tmp.bam"
    log="${LOG_ROOT}/${sample}.minimap2.log"

    mkdir -p "${outdir}"

    if [[ ! -s "${fq}" ]]; then
        echo "[ERROR] FASTQ not found or empty: ${fq}" >&2
        exit 1
    fi

    echo "[INFO] processing ${sample}"

    # 保留未剪引物的 raw BAM，后续检查 primer-binding site 突变
    "${MINIMAP2_BIN}" \
        -ax map-ont \
        -t "${THREADS}" \
        "${REF_MMI}" \
        "${fq}" \
        2> "${log}" \
        | "${SAMTOOLS_BIN}" sort \
            -@ "${THREADS}" \
            -o "${tmp_bam}" \
            -

    # 排序成功后再生成正式文件，避免保留不完整 BAM
    mv "${tmp_bam}" "${bam}"

    "${SAMTOOLS_BIN}" index -@ "${THREADS}" "${bam}"
    "${SAMTOOLS_BIN}" flagstat -@ "${THREADS}" "${bam}" \
        > "${outdir}/${sample}.flagstat.txt"

    echo "[INFO] finished ${sample}: ${bam}"
done < "${SAMPLE_LIST}"

echo "[INFO] all samples finished"
