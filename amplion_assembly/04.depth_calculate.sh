#!/bin/bash

# 1. 设定输入和输出目录
BAM_DIR="$WORK_DIR/03.minimap2"

# 2. 检查目录是否存在
if [ ! -d "$BAM_DIR" ]; then
    echo "错误: 找不到目录 $BAM_DIR"
    exit 1
fi

# 3. 遍历 04.minimap2 目录下所有的 sorted.bam 文件
for bam in "$BAM_DIR"/*.sorted.bam; do
    # 检查文件是否存在
    [ -f "$bam" ] || continue

    # 获取文件名（例如：FBH75672_3）
    filename=$(basename "$bam")
    SAMPLE_ID="${filename%.sorted.bam}"

    echo "=========================================="
    echo "=== 正在计算深度文件: ${SAMPLE_ID} ==="
    echo "输入 BAM 文件: ${bam}"
    echo "输出 TSV 文件: ${BAM_DIR}/${SAMPLE_ID}.depth.tsv"

    # 执行 samtools depth 计算深度
    conda run -n samtools_env samtools depth -aa "$bam" > "${BAM_DIR}/${SAMPLE_ID}.depth.tsv"

    echo -e "样本 ${SAMPLE_ID} 深度计算完成！\n"
done

echo "所有样本深度计算完毕！"
