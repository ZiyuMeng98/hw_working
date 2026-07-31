#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RAW_ROOT="${RAW_ROOT:-00.raw_data}"
OUT_ROOT="${OUT_ROOT:-.}"
SAMPLE_LIST="${SAMPLE_LIST:-${SCRIPT_DIR}/samples.txt}"

MIN_LEN="${MIN_LEN:-300}"
MAX_LEN="${MAX_LEN:-700}"
QUALITY="${QUALITY:-7}"
THREADS="${THREADS:-8}"
SKIP_QUALITY_CHECK="${SKIP_QUALITY_CHECK:-0}"

GUPPYPLEX_DIR="${OUT_ROOT}/01.artic_guppyplex"
LOG_DIR="${OUT_ROOT}/logs/01.artic_guppyplex"
SUMMARY="${GUPPYPLEX_DIR}/guppyplex_summary.tsv"

mkdir -p "${GUPPYPLEX_DIR}" "${LOG_DIR}"

printf "sample\traw_dir\tfastq_count\toutput_fastq\tmin_len\tmax_len\tquality\tstatus\n" > "${SUMMARY}"

while IFS= read -r sample || [[ -n "${sample}" ]]; do
  [[ -z "${sample}" || "${sample}" =~ ^# ]] && continue

  raw_dir="${RAW_ROOT}/${sample}"
  sample_out_dir="${GUPPYPLEX_DIR}/${sample}"
  sample_log_dir="${LOG_DIR}/${sample}"
  output_fastq="${sample_out_dir}/${sample}.artic_guppyplex.min${MIN_LEN}.max${MAX_LEN}.fastq.gz"
  log_file="${sample_log_dir}/${sample}.guppyplex.log"

  mkdir -p "${sample_out_dir}" "${sample_log_dir}"

  if [[ ! -d "${raw_dir}" ]]; then
    printf "%s\t%s\t0\t%s\t%s\t%s\t%s\tMISSING_RAW_DIR\n" \
      "${sample}" "${raw_dir}" "${output_fastq}" "${MIN_LEN}" "${MAX_LEN}" "${QUALITY}" >> "${SUMMARY}"
    echo "[ERROR] ${raw_dir} does not exist" >&2
    exit 1
  fi

  fastq_count="$(
    find "${raw_dir}" -type f \( \
      -name "*.fastq" -o -name "*.fq" -o -name "*.fastq.gz" -o -name "*.fq.gz" \
    \) | wc -l
  )"

  if [[ "${fastq_count}" -eq 0 ]]; then
    printf "%s\t%s\t0\t%s\t%s\t%s\t%s\tNO_FASTQ\n" \
      "${sample}" "${raw_dir}" "${output_fastq}" "${MIN_LEN}" "${MAX_LEN}" "${QUALITY}" >> "${SUMMARY}"
    echo "[ERROR] no FASTQ files found in ${raw_dir}" >&2
    exit 1
  fi

  cmd=(
    conda run -n artic_guppyplex_env artic guppyplex
    --directory "${raw_dir}"
    --min-length "${MIN_LEN}"
    --max-length "${MAX_LEN}"
    --quality "${QUALITY}"
    --output "${output_fastq}"
    --threads "${THREADS}"
  )

  # 某些历史 Guppy FASTQ 质量值不稳定时，可以设置 SKIP_QUALITY_CHECK=1 只做长度过滤。
  if [[ "${SKIP_QUALITY_CHECK}" == "1" ]]; then
    cmd+=(--skip-quality-check)
  fi

  echo "[INFO] running guppyplex for ${sample}"
  printf "Command: %q " "${cmd[@]}" > "${log_file}"
  printf "\n\n" >> "${log_file}"

  if "${cmd[@]}" >> "${log_file}" 2>&1; then
    if [[ ! -s "${output_fastq}" ]]; then
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\tEMPTY_OUTPUT\n" \
        "${sample}" "${raw_dir}" "${fastq_count}" "${output_fastq}" "${MIN_LEN}" "${MAX_LEN}" "${QUALITY}" >> "${SUMMARY}"
      echo "[ERROR] ${output_fastq} is empty; check ${log_file}" >&2
      exit 1
    fi

    # 每个样本独立记录输出路径，后续比对步骤直接读取该文件即可。
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\tOK\n" \
      "${sample}" "${raw_dir}" "${fastq_count}" "${output_fastq}" "${MIN_LEN}" "${MAX_LEN}" "${QUALITY}" >> "${SUMMARY}"
  else
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\tFAILED\n" \
      "${sample}" "${raw_dir}" "${fastq_count}" "${output_fastq}" "${MIN_LEN}" "${MAX_LEN}" "${QUALITY}" >> "${SUMMARY}"
    echo "[ERROR] guppyplex failed for ${sample}; check ${log_file}" >&2
    exit 1
  fi
done < "${SAMPLE_LIST}"

echo "[INFO] all samples finished. Summary: ${SUMMARY}"

