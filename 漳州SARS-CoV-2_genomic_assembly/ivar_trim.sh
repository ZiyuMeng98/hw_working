#!/usr/bin/env bash
set -euo pipefail

SAMPLE="barcode129"

RAW_BAM="02.minimap2/${SAMPLE}/${SAMPLE}.raw.sorted.bam"
PRIMER_BED="/home/mzy/working/20260730_20260723_12sample_XG/SARS-CoV-2_V5.4.2.primer.bed"
OUT_DIR="03.ivar_trim/${SAMPLE}"

IVAR_BIN="/home/mzy/.conda/envs/covid_amplicon/bin/ivar"
SAMTOOLS_BIN="/home/mzy/.conda/envs/covid_amplicon/bin/samtools"
THREADS=8

mkdir -p "${OUT_DIR}"

if [[ ! -s "${RAW_BAM}" ]]; then
    echo "[ERROR] BAM not found: ${RAW_BAM}" >&2
    exit 1
fi

if [[ ! -s "${PRIMER_BED}" ]]; then
    echo "[ERROR] primer BED not found: ${PRIMER_BED}" >&2
    exit 1
fi

if [[ ! -x "${IVAR_BIN}" ]]; then
    echo "[ERROR] ivar not executable: ${IVAR_BIN}" >&2
    exit 1
fi

PREFIX="${OUT_DIR}/${SAMPLE}.ivar"
TRIMMED_BAM="${OUT_DIR}/${SAMPLE}.trimmed.sorted.bam"

# 只剪引物，不启用 -e，避免未识别引物的 reads 把引物序列带入后续 consensus
"${IVAR_BIN}" trim \
    -i "${RAW_BAM}" \
    -b "${PRIMER_BED}" \
    -p "${PREFIX}" \
    -m 30 \
    -q 0 \
    -s 4

# iVar 输出的 BAM 再排序并建立索引
"${SAMTOOLS_BIN}" sort \
    -@ "${THREADS}" \
    -o "${TRIMMED_BAM}" \
    "${PREFIX}.bam"

"${SAMTOOLS_BIN}" index \
    -@ "${THREADS}" \
    "${TRIMMED_BAM}"

"${SAMTOOLS_BIN}" flagstat \
    "${TRIMMED_BAM}" \
    > "${OUT_DIR}/${SAMPLE}.trimmed.flagstat.txt"

"${SAMTOOLS_BIN}" quickcheck -v "${TRIMMED_BAM}"

echo "[INFO] finished: ${TRIMMED_BAM}"
