#!/bin/bash

INPUT_DIR="/home/mzy/working/20260721_Plasmodium/01.qc_and_host_result"
OUTPUT_DIR="/home/mzy/working/20260721_Plasmodium/02.kraken2_result"
DB_PATH="/data/database/kraken2_db/k2_pluspf_16gb"

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

    # Get sample_id from folder name
    sample_id=$(basename "$SAMPLE_DIR")

    echo -e "\n[$(date +'%Y-%m-%d %H:%M:%S')] Processing sample: ${sample_id} ..."

    r1_file=$(ls "$SAMPLE_DIR"/*_1.fastq.gz "$SAMPLE_DIR"/*_R1.fastq.gz "$SAMPLE_DIR"/*_1.fq.gz "$SAMPLE_DIR"/*_1.clean.fq.gz 2>/dev/null | head -n 1)
    r2_file=$(ls "$SAMPLE_DIR"/*_2.fastq.gz "$SAMPLE_DIR"/*_R2.fastq.gz "$SAMPLE_DIR"/*_2.fq.gz "$SAMPLE_DIR"/*_2.clean.fq.gz 2>/dev/null | head -n 1)

    echo "  Found R1: $r1_file"
    echo "  Found R2: $r2_file"

    conda run -n kraken2_env kraken2 --db "$DB_PATH" --threads "$THREADS" --paired --use-names --confidence "$CONFIDENCE" --report "$OUTPUT_DIR/${sample_id}.kreport" --output "$OUTPUT_DIR/${sample_id}.kraken" "$r1_file" "$r2_file"

    echo "sample name: ${sample_id} finished"
    echo "report file: $OUTPUT_DIR/${sample_id}.kreport"
done

echo -e "\n=================================================="
echo "All samples are finished!"
echo "Results saved in: $OUTPUT_DIR"
echo "=================================================="
