#!/bin/bash

# 1. 设定路径
INPUT_DIR="$WORK_DIR/02.cutadapt"
OUT_DIR="$WORK_DIR/03.minimap2"

# REF_FA="$HOME/reference/MN908947.3/MN908947.3.fa"

# 2. 创建输出目录
mkdir -p "$OUT_DIR"

# 3. 遍历 09.cutadapt 目录下所有 trimmed.fastq.gz 文件
for fq in "$INPUT_DIR"/*.filter.fastq.gz; do
    # 检查文件是否存在
    [ -f "$fq" ] || continue

    # 获取文件名（例如：FBH75672_3）
    filename=$(basename "$fq")
    SAMPLE_ID="${filename%.filter.fastq.gz}"

    echo "=========================================="
    echo "=== 正在处理样本比对与排序: ${SAMPLE_ID} ==="

    # 步骤 1: Minimap2 比对生成 SAM
    echo "1/4 正在进行 Minimap2 比对..."
    conda run -n minimap2_env minimap2 \
      -ax map-ont \
      -t 8 \
      "$REF_FA" \
      "$fq" > "${OUT_DIR}/${SAMPLE_ID}.sam"

    # 步骤 2: Samtools view 将 SAM 转为未排序 BAM
    echo "2/4 正在将 SAM 转换为未排序 BAM..."
    conda run -n samtools_env samtools view \
      -bS \
      -o "${OUT_DIR}/${SAMPLE_ID}.unsorted.bam" \
      "${OUT_DIR}/${SAMPLE_ID}.sam"

    # 步骤 3: Samtools sort 排序 BAM
    echo "3/4 正在对 BAM 进行排序..."
    conda run -n samtools_env samtools sort \
      -@ 8 \
      -o "${OUT_DIR}/${SAMPLE_ID}.sorted.bam" \
      "${OUT_DIR}/${SAMPLE_ID}.unsorted.bam"

    # 步骤 4: Samtools index 建立索引
    echo "4/4 正在建立 BAM 索引..."
    conda run -n samtools_env samtools index "${OUT_DIR}/${SAMPLE_ID}.sorted.bam"

    # 步骤 5: 清理中间的临时文件（SAM 和 unsorted.bam）
    rm -f "${OUT_DIR}/${SAMPLE_ID}.sam" "${OUT_DIR}/${SAMPLE_ID}.unsorted.bam"

    echo -e "样本 ${SAMPLE_ID} 比对和索引建立完成！\n"
done
