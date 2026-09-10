#!/bin/bash

VCF_DIR="$WORK_DIR/04.freebayes"
BED_DIR="$WORK_DIR/03.minimap2"
OUT_DIR="$WORK_DIR/05.consensus"
# REF_FA="$HOME/reference/MN908947.3/MN908947.3.fa"

mkdir -p "$OUT_DIR"

for vcf in "$VCF_DIR"/*.pass.vcf.gz; do
    [ -f "$vcf" ] || continue

    filename=$(basename "$vcf")
    SAMPLE_ID="${filename%.*}"

    LOWCOV_BED="${BED_DIR}/${SAMPLE_ID}.lowcov.bed"
    if [ ! -f "$LOWCOV_BED" ]; then
        NUM=$(echo "$SAMPLE_ID" | grep -oE "[0-9]+" | tail -n 1)
        PAD_NUM=$(printf "%02d" "$NUM" 2>/dev/null)
        MATCHED_BED=$(ls ${BED_DIR}/*barcode${PAD_NUM}*.lowcov.bed ${BED_DIR}/*barcode${NUM}*.lowcov.bed 2>/dev/null | head -n 1)
        if [ -n "$MATCHED_BED" ]; then
            LOWCOV_BED="$MATCHED_BED"
        fi
    fi

    echo "=========================================="
    echo "Processing Consensus FASTA: ${SAMPLE_ID}"

    if [ ! -f "$LOWCOV_BED" ]; then
        echo "Warning: No matching lowcov.bed found for ${SAMPLE_ID}, running without mask."
        conda run -n bcftools_env bcftools consensus -f "$REF_FA" "$vcf" > "${OUT_DIR}/${SAMPLE_ID}.consensus.fasta"
    else
        echo "Using mask BED file: ${LOWCOV_BED}"
        conda run -n bcftools_env bcftools consensus -f "$REF_FA" -m "$LOWCOV_BED" "$vcf" > "${OUT_DIR}/${SAMPLE_ID}.consensus.fasta"
    fi

    sed -i "1s/>.*/>${SAMPLE_ID}/" "${OUT_DIR}/${SAMPLE_ID}.consensus.fasta"
    echo "Finished ${SAMPLE_ID}. Header: $(head -n 1 ${OUT_DIR}/${SAMPLE_ID}.consensus.fasta)"
    echo ""
done

echo "All consensus sequences generated in ${OUT_DIR}/"
