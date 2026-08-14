#!/bin/bash

# 解决终端中文乱码
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# 定义 Conda 环境中的 samtools 调用命令
SAMTOOLS="conda run -n samtools_env samtools"

# 设置工作目录并去除末尾的多余斜杠
PARENT_DIR="${1:-.}"
PARENT_DIR="${PARENT_DIR%/}"

echo "=================================================="
echo " 开始批量处理：扫描目录 ${PARENT_DIR}"
echo " 指定 Conda 环境: samtools_env"
echo "=================================================="

# 遍历根目录下的所有子文件夹（即样本文件夹）
for SAMPLE_DIR in "$PARENT_DIR"/*; do
    if [ -d "$SAMPLE_DIR" ]; then
        SAMPLE_NAME=$(basename "$SAMPLE_DIR")
        echo -e "\n--------------------------------------------------"
        echo "正在处理样本: [ ${SAMPLE_NAME} ]"
        
        # 1. 严格寻找原始 BAM 文件（排除包含 top10 的中间/结果文件）
        BAM_FILE=$(find "$SAMPLE_DIR" -maxdepth 1 -type f -name "*.bam" ! -name "*top10*" | sort | head -n 1)

        # 检查是否找到 BAM 文件
        if [ -z "$BAM_FILE" ]; then
            echo "[跳过] 在 ${SAMPLE_DIR} 中未找到任何原始 .bam 文件。"
            continue
        fi
        echo "找到原始 BAM 文件: ${BAM_FILE}"

        # 2. 检查索引文件 (.bai)，不存在则建立索引
        if [ ! -f "${BAM_FILE}.bai" ] && [ ! -f "${BAM_FILE%.bam}.bai" ]; then
            echo "未找到 .bai 索引文件，正在自动创建索引..."
            $SAMTOOLS index "$BAM_FILE"
        fi

        # 3. 定义该样本专有的输出文件名
        TOP10_TXT="${SAMPLE_DIR}/${SAMPLE_NAME}_top10_targets.txt"
        TOP10_BAM="${SAMPLE_DIR}/${SAMPLE_NAME}_top10_reads.bam"
        TOP10_FASTQ="${SAMPLE_DIR}/${SAMPLE_NAME}_top10_reads.fastq"
        SUMMARY_TXT="${SAMPLE_DIR}/${SAMPLE_NAME}_top10_summary.txt"

        # 清理旧的可能已损坏的中间文件
        rm -f "$TOP10_BAM" "$TOP10_FASTQ"

        # 4. 统计 Top 10 参考序列（去除 Windows 换行符与 * 未比对项）
        echo ">>> [1/3] 统计比对 Reads 数量前 10 的参考序列..."
        $SAMTOOLS idxstats "$BAM_FILE" | grep -v '^\*' | sort -k3,3nr | head -n 10 | \
        awk '{printf "参考序列: %-30s 长度: %-10s 比对Reads数: %s\n", $1, $2, $3}' | tee "$SUMMARY_TXT"

        # 5. 提取 Top 10 序列名称存入临时列表
        $SAMTOOLS idxstats "$BAM_FILE" | grep -v '^\*' | sort -k3,3nr | head -n 10 | cut -f1 | tr -d '\r' > "$TOP10_TXT"

        # 检查是否有比对成功的序列
        if [ ! -s "$TOP10_TXT" ]; then
            echo "[警告] 样本 ${SAMPLE_NAME} 没有任何 Read 比对上参考序列，跳过提取。"
            rm -f "$TOP10_TXT"
            continue
        fi

        # 6. 根据 Top 10 目标列表提取 BAM（使用 -o 参数直接写入文件，避免重定向污染）
        echo ">>> [2/3] 提取 Top 10 比对区域的 BAM 数据..."
        mapfile -t TARGET_ARRAY < "$TOP10_TXT"
        $SAMTOOLS view -b -h -o "$TOP10_BAM" "$BAM_FILE" "${TARGET_ARRAY[@]}"

        # 校验生成的 BAM 文件是否有效且非空
        if [ ! -s "$TOP10_BAM" ]; then
            echo "[错误] 生成的 ${TOP10_BAM} 为空文件，跳过 FASTQ 转换。"
            continue
        fi

        # 7. 将 BAM 转换为 FASTQ
        echo ">>> [3/3] 导出 FASTQ 文件..."
        $SAMTOOLS fastq "$TOP10_BAM" > "$TOP10_FASTQ"

        if [ -s "$TOP10_FASTQ" ]; then
            echo "[成功] 样本 ${SAMPLE_NAME} 处理完毕！"
            echo "      生成文件: ${TOP10_FASTQ}"
        else
            echo "[错误] 样本 ${SAMPLE_NAME} FASTQ 导出为空，请检查 BAM 文件内容。"
        fi
    fi
done

echo -e "\n=================================================="
echo " 所有样本批量处理完成！"
echo "=================================================="
