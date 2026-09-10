#!/bin/bash

# 1. 设定目录
BAM_DIR="$WORK_DIR/03.minimap2"

# 2. 检查目录是否存在
if [ ! -d "$BAM_DIR" ]; then
    echo "错误: 找不到目录 $BAM_DIR"
    exit 1
fi

# 3. 遍历 03.minimap2 目录下所有的 .depth.tsv 文件
for depth_file in "$BAM_DIR"/*.depth.tsv; do
    # 检查文件是否存在
    [ -f "$depth_file" ] || continue

    # 获取样本 ID（例如：FBH75672_3）
    filename=$(basename "$depth_file")
    SAMPLE_ID="${filename%.depth.tsv}"

    echo "=========================================="
    echo "=== 正在处理低深度区域 BED 文件: ${SAMPLE_ID} ==="

    # 步骤 1: awk 提取深度小于 10 的位点转为 0-based BED 格式
    echo "1/3 提取低深度 (depth < 10) 位点..."
    awk '$3 < 10 {print $1"\t"$2-1"\t"$2}' "$depth_file" > "${BAM_DIR}/${SAMPLE_ID}.raw.bed"

    # 步骤 2: bedtools sort 排序
    echo "2/3 对 BED 文件进行排序..."
    conda run -n bedtools_env bedtools sort -i "${BAM_DIR}/${SAMPLE_ID}.raw.bed" > "${BAM_DIR}/${SAMPLE_ID}.sorted.bed"

    # 步骤 3: bedtools merge 合并连续区间
    echo "3/3 合并重叠与相邻区间..."
    conda run -n bedtools_env bedtools merge -i "${BAM_DIR}/${SAMPLE_ID}.sorted.bed" > "${BAM_DIR}/${SAMPLE_ID}.lowcov.bed"

    # 步骤 4: 清理中间产生的临时 BED 文件
    rm -f "${BAM_DIR}/${SAMPLE_ID}.raw.bed" "${BAM_DIR}/${SAMPLE_ID}.sorted.bed"

    echo -e "样本 ${SAMPLE_ID} 低深度区间合并完成！生成文件: ${BAM_DIR}/${SAMPLE_ID}.lowcov.bed\n"
done

echo "所有样本的低深度区间（lowcov.bed）提取完毕！"
