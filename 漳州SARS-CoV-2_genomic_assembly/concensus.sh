#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SAMPLE_LIST="/home/mzy/working/20260812_SARS_Cov/samples.txt"
REF_FA="/home/mzy/reference/MN908947.3/MN908947.3.fa"

BAM_ROOT="/home/mzy/working/20260812_SARS_Cov/03.ivar_trim"
OUT_ROOT="/home/mzy/working/20260812_SARS_Cov/06.consensus"
LOG_ROOT="/home/mzy/working/20260812_SARS_Cov06.consensus"

SAMTOOLS_BIN="${SAMTOOLS_BIN:-/home/mzy/.conda/envs/covid_amplicon/bin/samtools}"
IVAR_BIN="${IVAR_BIN:-/home/mzy/.conda/envs/covid_amplicon/bin/ivar}"

THREADS="${THREADS:-8}"
MIN_DEPTH="${MIN_DEPTH:-1}"
MIN_FREQ="${MIN_FREQ:-0.50}"
MIN_BASEQ="${MIN_BASEQ:-0}"

mkdir -p "${OUT_ROOT}" "${LOG_ROOT}"

if [[ ! -s "${SAMPLE_LIST}" ]]; then
  echo "[ERROR] sample list not found: ${SAMPLE_LIST}" >&2
  exit 1
fi

if [[ ! -s "${REF_FA}" ]]; then
  echo "[ERROR] reference FASTA not found: ${REF_FA}" >&2
  exit 1
fi

if [[ ! -x "${SAMTOOLS_BIN}" ]]; then
  echo "[ERROR] samtools not executable: ${SAMTOOLS_BIN}" >&2
  exit 1
fi

if [[ ! -x "${IVAR_BIN}" ]]; then
  echo "[ERROR] ivar not executable: ${IVAR_BIN}" >&2
  exit 1
fi

if [[ ! -s "${REF_FA}.fai" ]]; then
  "${SAMTOOLS_BIN}" faidx "${REF_FA}"
fi

ALL_VARIANTS="${OUT_ROOT}/all_samples.variants.tsv"
ALL_CONSENSUS="${OUT_ROOT}/all_samples.consensus.fa"

rm -f "${ALL_VARIANTS}" "${ALL_CONSENSUS}"

while IFS= read -r sample || [[ -n "${sample}" ]]; do
  [[ -z "${sample}" || "${sample}" =~ ^# ]] && continue

  echo "[INFO] processing ${sample}"

  outdir="${OUT_ROOT}/${sample}"
  mkdir -p "${outdir}"

  bam="${BAM_ROOT}/${sample}/${sample}.trimmed.sorted.bam"

  if [[ ! -s "${bam}" ]]; then
    echo "[ERROR] trimmed BAM not found: ${bam}" >&2
    exit 1
  fi

  "${SAMTOOLS_BIN}" quickcheck -v "${bam}"

  if [[ ! -s "${bam}.bai" ]]; then
    "${SAMTOOLS_BIN}" index "${bam}"
  fi

  variant_prefix="${outdir}/${sample}.variants"
  consensus_prefix="${outdir}/${sample}.consensus"

  # variants：记录样本相对参考的突变信息，方便后续人工排查。
  "${SAMTOOLS_BIN}" mpileup \
    -aa \
    -A \
    -d 0 \
    -Q "${MIN_BASEQ}" \
    -f "${REF_FA}" \
    "${bam}" \
    | "${IVAR_BIN}" variants \
        -p "${variant_prefix}" \
        -q "${MIN_BASEQ}" \
        -t "${MIN_FREQ}" \
        -m "${MIN_DEPTH}"

  # consensus：低于 MIN_DEPTH 的位置会被写成 N。
  "${SAMTOOLS_BIN}" mpileup \
    -aa \
    -A \
    -d 0 \
    -Q "${MIN_BASEQ}" \
    -f "${REF_FA}" \
    "${bam}" \
    | "${IVAR_BIN}" consensus \
        -p "${consensus_prefix}" \
        -q "${MIN_BASEQ}" \
        -t "${MIN_FREQ}" \
        -m "${MIN_DEPTH}" \
        -n N

  sed -i "s/^>.*/>${sample}/" "${consensus_prefix}.fa"

  if [[ ! -s "${ALL_VARIANTS}" ]]; then
    awk -v s="${sample}" 'BEGIN{FS=OFS="\t"} NR==1{print "sample",$0; next} NR>1{print s,$0}' "${variant_prefix}.tsv" > "${ALL_VARIANTS}"
  else
    awk -v s="${sample}" 'BEGIN{FS=OFS="\t"} NR>1{print s,$0}' "${variant_prefix}.tsv" >> "${ALL_VARIANTS}"
  fi

  cat "${consensus_prefix}.fa" >> "${ALL_CONSENSUS}"

  echo "[INFO] finished ${sample}"
done < "${SAMPLE_LIST}"

echo "[INFO] all variants: ${ALL_VARIANTS}"
echo "[INFO] all consensus fasta: ${ALL_CONSENSUS}"
