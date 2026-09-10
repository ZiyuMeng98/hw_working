#!/bin/bash

# 1. 设定输入、输出路径和参考基因组
INPUT_DIR="$WORK_DIR/03.minimap2"
OUT_DIR="$WORK_DIR/04.freebayes"
# REF_FA="$HOME/reference/MN908947.3/MN908947.3.fa"

# 2. 检查输入目录是否存在，并创建输出目录
if [ ! -d "$INPUT_DIR" ]; then
    echo "错误: 找不到输入目录 $INPUT_DIR"
    exit 1
fi

mkdir -p "$OUT_DIR"

# 3. 遍历 10.minimap2 目录下所有的 .sorted.bam 文件
for bam in "$INPUT_DIR"/*.sorted.bam; do
    # 检查文件是否存在
    [ -f "$bam" ] || continue

    # 获取样本 ID（例如：FBH75672_3）
    filename=$(basename "$bam")
    SAMPLE_ID="${filename%.sorted.bam}"

    echo "=========================================="
    echo "=== 正在进行 FreeBayes 变异检测: ${SAMPLE_ID} ==="
    echo "输入 BAM 文件: ${bam}"
    echo "输出 VCF 文件: ${OUT_DIR}/${SAMPLE_ID}.raw.vcf"

    # 执行 FreeBayes 呼叫变异
    conda run -n freebayes_env freebayes \
      -f "$REF_FA" \
      --ploidy 1 \
      --min-coverage 20 \
      --min-alternate-count 5 \
      --min-alternate-fraction 0.50 \
      --min-base-quality 10 \
      --min-mapping-quality 20 \
      "$bam" > "${OUT_DIR}/${SAMPLE_ID}.raw.vcf"

    echo -e "样本 ${SAMPLE_ID} 变异检测完成！\n"
done

echo "所有样本的 FreeBayes 变异检测已全部完成！"
