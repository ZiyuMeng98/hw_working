#!/bin/bash

# 1. 请修改为您服务器上 Kraken2 数据库的真实绝对路径
KRAKEN2_DB="/data/database/kraken2_db/k2_pluspf_16gb/"

# 2. 设置 Conda 环境中的 kraken2 调用命令
KRAKEN2_CMD="conda run -n kraken2_env kraken2"

# 3. 设置使用的 CPU 线程数
THREADS=8

# 解决终端中文乱码
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

PARENT_DIR="${1:-.}"
PARENT_DIR="${PARENT_DIR%/}"

# 定义统一汇总保存的文件夹与压缩包路径
SUMMARY_DIR="${PARENT_DIR}/kraken2_reports_summary"
ARCHIVE_FILE="${PARENT_DIR}/kraken2_reports_summary.tar.gz"

mkdir -p "$SUMMARY_DIR"

echo "=================================================="
echo " 开始批量运行 Kraken2 物种分类分析"
echo " 数据库路径: ${KRAKEN2_DB}"
echo " 报告汇总目录: ${SUMMARY_DIR}"
echo "=================================================="

# 检查数据库路径有效性
if [ ! -d "$KRAKEN2_DB" ]; then
    echo "[错误] 数据库目录不存在: ${KRAKEN2_DB}"
    echo "请打开脚本将 KRAKEN2_DB 变量修改为正确的数据库路径！"
    exit 1
fi

# 遍历各样本文件夹
for SAMPLE_DIR in "$PARENT_DIR"/*; do
    if [ -d "$SAMPLE_DIR" ] && [ "$(realpath "$SAMPLE_DIR")" != "$(realpath "$SUMMARY_DIR")" ]; then
        SAMPLE_NAME=$(basename "$SAMPLE_DIR")
        FASTQ_FILE="${SAMPLE_DIR}/${SAMPLE_NAME}_top10_reads.fastq"

        # 检查 FASTQ 是否存在且非空
        if [ ! -s "$FASTQ_FILE" ]; then
            echo "[跳过] 样本 ${SAMPLE_NAME} 下未找到有效的 ${SAMPLE_NAME}_top10_reads.fastq"
            continue
        fi

        echo -e "\n--------------------------------------------------"
        echo "正在鉴定样本 [ ${SAMPLE_NAME} ] ..."

        REPORT_FILE="${SAMPLE_DIR}/${SAMPLE_NAME}_kraken2_report.txt"
        OUTPUT_FILE="${SAMPLE_DIR}/${SAMPLE_NAME}_kraken2_output.txt"

        # 运行 Kraken2 分类
        $KRAKEN2_CMD --db "$KRAKEN2_DB" \
                     --threads "$THREADS" \
                     --report "$REPORT_FILE" \
                     --output "$OUTPUT_FILE" \
                     "$FASTQ_FILE"

        if [ -s "$REPORT_FILE" ]; then
            # 自动复制一份到集中汇总目录
            cp "$REPORT_FILE" "${SUMMARY_DIR}/"

            echo "[完成] 样本 ${SAMPLE_NAME} 分析完毕！"
            echo "      样本目录报告: ${REPORT_FILE}"
            echo "      已同步复制至: ${SUMMARY_DIR}/"

            # 终端实时预览 Top 5 丰度最高的“种 (Species)”水平结果
            echo -e "\n>>> 样本 [ ${SAMPLE_NAME} ] 丰度前 5 的物种 (Species)："
            awk '$4=="S" {printf "  - 占比: %6s%%   Reads数: %-8s 物种名: %s\n", $1, $2, substr($0, index($0,$6))}' "$REPORT_FILE" | head -n 5
        else
            echo "[错误] 样本 ${SAMPLE_NAME} 未能正常生成 report 报告。"
        fi
    fi
done

# 生成所有样本主导物种的多样本对比总表
COMBINED_SUMMARY="${SUMMARY_DIR}/all_samples_top_species_summary.txt"
echo "==================================================" > "$COMBINED_SUMMARY"
echo " 所有样本 Kraken2 丰度前 3 物种汇总总表" >> "$COMBINED_SUMMARY"
echo "==================================================" >> "$COMBINED_SUMMARY"

for r in "$SUMMARY_DIR"/*_kraken2_report.txt; do
    if [ -f "$r" ]; then
        s_name=$(basename "$r" _kraken2_report.txt)
        echo -e "\n【样本名: ${s_name}】" >> "$COMBINED_SUMMARY"
        awk '$4=="S" {printf "  占比: %6s%%   Reads数: %-8s 物种: %s\n", $1, $2, substr($0, index($0,$6))}' "$r" | head -n 3 >> "$COMBINED_SUMMARY"
    fi
done

# 自动打包为 .tar.gz 格式压缩包
echo -e "\n--------------------------------------------------"
echo "正在将汇总文件夹打包为压缩文件..."
tar -czf "$ARCHIVE_FILE" -C "$PARENT_DIR" "$(basename "$SUMMARY_DIR")"

echo -e "\n=================================================="
echo " 所有样本 Kraken2 分类及汇总完成！"
echo " 1. 汇总文件夹路径: ${SUMMARY_DIR}/"
echo " 2. 全样本物种总表: ${COMBINED_SUMMARY}"
echo " 3. 可直接下载的压缩包: ${ARCHIVE_FILE}"
echo "=================================================="
