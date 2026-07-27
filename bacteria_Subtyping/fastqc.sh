#!/bin/bash

RAW_DIR="/home/user/working/20260727_kongchang_Subtyping/00.rawdata"
QC_DIR="/home/user/working/20260727_kongchang_Subtyping/01.fastqc"

for sample_dir in "$RAW_DIR"/*/; do
    if [ -d "$sample_dir" ]; then
        sample_name=$(basename "$sample_dir")
        
        out_dir="$QC_DIR/$sample_name"
        mkdir -p "$out_dir"
        
        echo "=========================================="
        echo "Run [ $sample_name ] FastQC..."
        echo "=========================================="
        
        conda run -n fastqc_env fastqc -o "$out_dir" -t 4 "$sample_dir"/*.fq.gz
    fi
done

echo "All sample FastQC finished！"
