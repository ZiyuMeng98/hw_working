#!/bin/bash

DATA_DIR="/data1/guojie/project/tianjing/ccy"
OUT_DIR="/home/mzy/working/20260721_Plasmodium/01.qc_and_host_result"
LOG_DIR="/home/mzy/working/20260721_Plasmodium/01.qc_and_host_result_logs"
REPORT_DIR="/home/mzy/working/20260721_Plasmodium/01.qc_and_host_result_reports"

HUMAN_INDEX="/data/database/GRCh38/GRCh38"
THREADS=32

STATS_FILE="${OUT_DIR}/host_abundance_summary.tsv"

mkdir -p "${OUT_DIR}" "${LOG_DIR}" "${REPORT_DIR}"

# 初始化汇总表格表头
echo -e "Sample\tRaw_Reads\tClean_Reads\tHost_Reads\tHost_Ratio(%)\tParasite_Reads\tParasite_Ratio(%)" > "${STATS_FILE}"

echo "========== Processing begin =========="

for SAMPLE_DIR in "${DATA_DIR}"/*/; do
    [ -d "${SAMPLE_DIR}" ] || continue
    SAMPLE_NAME=$(basename "${SAMPLE_DIR}")
    
    [ "${SAMPLE_NAME}" = "01.qc" ] && continue

    SAMPLE_OUT_DIR="${OUT_DIR}/${SAMPLE_NAME}"
    mkdir -p "${SAMPLE_OUT_DIR}"

    # 获取输入文件路径
    R1=$(ls ${SAMPLE_DIR}/*_1.fq.gz ${SAMPLE_DIR}/*_1.fastq.gz ${SAMPLE_DIR}/*_R1_001.fastq.gz 2>/dev/null | head -n 1)
    [ -z "${R1}" ] && echo "${SAMPLE_NAME} do not have R1，pass" && continue

    R2=$(echo "${R1}" | sed 's/_1\./_2\./; s/_R1_001/_R2_001/')

    CLEAN_R1="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_clean_1.fq.gz"
    CLEAN_R2="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_clean_2.fq.gz"
    PARASITE_FASTQ="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_parasite_R%.fq.gz"

    echo ">>> running: ${SAMPLE_NAME}"

    # fastp
    FASTP_JSON="${REPORT_DIR}/${SAMPLE_NAME}_fastp.json"
    FASTP_LOG="${LOG_DIR}/${SAMPLE_NAME}_fastp.log"
    
    conda run -n fastp_env fastp -i "${R1}" -I "${R2}" -o "${CLEAN_R1}" -O "${CLEAN_R2}" --thread ${THREADS} -h "${REPORT_DIR}/${SAMPLE_NAME}_fastp.html" -j "${FASTP_JSON}" > "${FASTP_LOG}" 2>&1

    # Bowtie2 去宿主
    BOWTIE2_LOG="${LOG_DIR}/${SAMPLE_NAME}_bowtie2_host.log"
    
    conda run -n bowtie2_env bowtie2 -x "${HUMAN_INDEX}" -1 "${CLEAN_R1}" -2 "${CLEAN_R2}" --very-sensitive-local --un-conc-gz "${PARASITE_FASTQ}" -p ${THREADS} > /dev/null 2> "${BOWTIE2_LOG}"

    # 计算宿主占比
    RAW_READS=$(python3 -c "import json; j=json.load(open('${FASTP_JSON}')); print(j['summary']['before_filtering']['total_reads'])" 2>/dev/null || echo "0")
    CLEAN_READS=$(python3 -c "import json; j=json.load(open('${FASTP_JSON}')); print(j['summary']['after_filtering']['total_reads'])" 2>/dev/null || echo "0")
    
    # 从 bowtie2 log 中解析宿主比对率 (整体比对率 %)
    HOST_RATIO=$(grep "overall alignment rate" "${BOWTIE2_LOG}" | grep -oP '\d+(\.\d+)?(?=%)' || echo "0")

    # 计算具体 Reads 数量与比例
    if [ "${CLEAN_READS}" -gt 0 ] && [ -n "${HOST_RATIO}" ]; then
        HOST_READS=$(python3 -c "print(int(${CLEAN_READS} * (${HOST_RATIO} / 100.0)))")
        PARASITE_READS=$(python3 -c "print(${CLEAN_READS} - ${HOST_READS})")
        PARASITE_RATIO=$(python3 -c "print(round(100.0 - ${HOST_RATIO}, 2))")
    else
        HOST_READS="N/A"
        PARASITE_READS="N/A"
        PARASITE_RATIO="N/A"
    fi

    # 写入统计文件
    echo -e "${SAMPLE_NAME}\t${RAW_READS}\t${CLEAN_READS}\t${HOST_READS}\t${HOST_RATIO}%\t${PARASITE_READS}\t${PARASITE_RATIO}%" >> "${STATS_FILE}"


    echo "${SAMPLE_NAME} finished | Host proportion: ${HOST_RATIO}% | Proportion of malaria parasites: ${PARASITE_RATIO}%"
done

echo "========== Processing complete =========="
echo "The summary statistics file has been saved in: ${STATS_FILE}"
echo "------------------------------------------------"
cat "${STATS_FILE}"
