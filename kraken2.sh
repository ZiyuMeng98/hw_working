#!/bin/bash

INPUT_DIR="/home/user/working/01.qc_and_host_result"
OUTPUT_DIR="/home/user/working/02.kraken2_result"
DB_PATH="/home/user/database/kraken2_db/k2_pluspf_16gb/"

THREADS=32
CONFIDENCE=0.1

mkdir -p "$OUTPUT_DIR"

echo "=================================================="
echo "Starting Kraken2 batch species identification"
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Database path: $DB_PATH"
echo "=================================================="

for SAMPLE_DIR in "$INPUT_DIR"/*/ ; do
    [ -d "$SAMPLE_DIR" ] || continue

    sample_id=$(basename "$SAMPLE_DIR")
    echo -e "\n[$(date +'%Y-%m-%d %H:%M:%S')] Processing sample: ${sample_id} ..."

    # 定位 R1 文件
    r1_file=$(ls "$SAMPLE_DIR"/*parasite*{_1,_R1}*.{fq,fastq}.gz 2>/dev/null | head -n 1)

    # 动态替换获取 R2 文件名
    if [[ "$r1_file" == *"_1."* ]]; then
        r2_file="${r1_file/_1./_2.}"
    elif [[ "$r1_file" == *"_R1."* ]]; then
        r2_file="${r1_file/_R1./_R2.}"
    elif [[ "$r1_file" == *"_1_"* ]]; then
        r2_file="${r1_file/_1_/_2_}"
    elif [[ "$r1_file" == *"_R1_"* ]]; then
        r2_file="${r1_file/_R1_/_R2_}"
    fi

    echo "  Found R1: $r1_file"
    echo "  Found R2: $r2_file"

    # 执行 Kraken2
    conda run -n kraken2_env kraken2 \
        --db "$DB_PATH" \
        --threads "$THREADS" \
        --paired \
        --use-names \
        --gzip-compressed \
        --confidence "$CONFIDENCE" \
        --report "$OUTPUT_DIR/${sample_id}.kreport" \
        --output "$OUTPUT_DIR/${sample_id}.kraken" \
        "$r1_file" "$r2_file"

    echo "sample name: ${sample_id} finished"
    echo "report file: $OUTPUT_DIR/${sample_id}.kreport"
done

echo -e "\n=================================================="
echo "All samples are finished!"
echo "Results saved in: $OUTPUT_DIR"
echo "=================================================="
