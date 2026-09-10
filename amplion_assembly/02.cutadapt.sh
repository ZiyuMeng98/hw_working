#!/bin/bash

# 1. 设定路径
RAW_DIR="$WORK_DIR/01.artic_guppyplex"
OUT_DIR="$WORK_DIR/02.cutadapt"

# 2. 创建输出目录
mkdir -p "$OUT_DIR"

# 3. 遍历 01.artic_guppyplex 下的每个子文件夹
for sample_dir in "$RAW_DIR"/*/; do
    # 检查是否为目录
    [ -d "$sample_dir" ] || continue

    # 获取文件夹名称作为样本名（如 barcode01）
    SAMPLE_ID=$(basename "$sample_dir")

    # 检索该文件夹内的 .artic_guppyplex.min300.fastq.gz 文件
    FASTQ_FILE=$(find "$sample_dir" -maxdepth 1 -type f -name "*.filter.fastq.gz" | head -n 1)

    if [ -n "$FASTQ_FILE" ]; then
        echo "=========================================="
        echo "=== 正在处理样本: ${SAMPLE_ID} ==="
        echo "输入 FASTQ 文件: ${FASTQ_FILE}"

        # 运行 Cutadapt 进行引物切除与质控过滤
        conda run -n cutadapt_env cutadapt \
          -g "file:$LEFT_FASTA" \
          -a "file:$RIGHT_FASTA" \
          --discard-untrimmed \
          -q 10 \
          -m 300 \
          -j 8 \
          -o "${OUT_DIR}/${SAMPLE_ID}.filter.fastq.gz" \
          "$FASTQ_FILE"

        echo -e "样本 ${SAMPLE_ID} 处理完成！\n"
    else
        echo "警告: 在目录 ${sample_dir} 中未找到目标 FASTQ 文件，跳过此文件夹。"
    fi
done
