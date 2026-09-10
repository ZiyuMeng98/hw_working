#!/bin/bash

# 1. 设定路径和参考基因组
VCF_DIR="$WORK_DIR/04.freebayes"
# REF_FA="$HOME/reference/MN908947.3/MN908947.3.fa"

# 2. 检查目录是否存在
if [ ! -d "$VCF_DIR" ]; then
    echo "错误: 找不到目录 $VCF_DIR"
    exit 1
fi

# 3. 遍历 05.freebayes 目录下所有的 .raw.vcf 文件
for vcf in "$VCF_DIR"/*.raw.vcf; do
    # 检查文件是否存在
    [ -f "$vcf" ] || continue

    # 获取样本 ID（例如：FBH75672_3）
    filename=$(basename "$vcf")
    SAMPLE_ID="${filename%.raw.vcf}"

    echo "=========================================="
    echo "=== 正在处理 VCF 规范化与过滤: ${SAMPLE_ID} ==="

    # 步骤 1: bgzip 压缩并建立索引
    echo "1/5 正在压缩 raw.vcf 并建立索引..."
    bgzip -c "${VCF_DIR}/${SAMPLE_ID}.raw.vcf" > "${VCF_DIR}/${SAMPLE_ID}.raw.vcf.gz"
    tabix -p vcf "${VCF_DIR}/${SAMPLE_ID}.raw.vcf.gz"

    # 步骤 2: bcftools norm 标准化多等位基因与 InDel 位点
    echo "2/5 正在进行 bcftools norm 位点标准化..."
    conda run -n bcftools_env bcftools norm \
      -f "$REF_FA" \
      -m -any \
      "${VCF_DIR}/${SAMPLE_ID}.raw.vcf.gz" \
      -Oz -o "${VCF_DIR}/${SAMPLE_ID}.norm.vcf.gz"

    # 步骤 3: 为 norm.vcf.gz 建立索引
    echo "3/5 建立 norm.vcf.gz 索引..."
    tabix -p vcf "${VCF_DIR}/${SAMPLE_ID}.norm.vcf.gz"

    # 步骤 4: bcftools filter 过滤高质量变异 (QUAL>=20 且 DP>=20)
    echo "4/5 正在过滤高质量变异位点..."
    conda run -n bcftools_env bcftools filter \
      -i 'QUAL>=20 && INFO/DP>=20' \
      "${VCF_DIR}/${SAMPLE_ID}.norm.vcf.gz" \
      -Oz -o "${VCF_DIR}/${SAMPLE_ID}.pass.vcf.gz"

    # 步骤 5: 为 pass.vcf.gz 建立索引（后续 consensus 生成的必需文件）
    echo "5/5 建立 pass.vcf.gz 索引..."
    tabix -p vcf "${VCF_DIR}/${SAMPLE_ID}.pass.vcf.gz"

    echo -e "样本 ${SAMPLE_ID} VCF 处理与过滤已完成！\n"
done

echo "所有样本的 VCF 过滤与索引已全部完成！"
