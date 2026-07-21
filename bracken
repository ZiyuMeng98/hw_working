#!/bin/bash

# ==============================================================================
# Path and parameter configurations
# ==============================================================================
INPUT_DIR="/home/mzy/working/20260721_Plasmodium/02.kraken2_result"
OUTPUT_DIR="/home/mzy/working/20260721_Plasmodium/03.bracken_result"
DB_PATH="/data/database/kraken2_db/k2_pluspf_16gb"

READ_LEN=150
LEVEL="S"

mkdir -p "$OUTPUT_DIR"

echo "=================================================="
echo "Starting Bracken batch abundance re-estimation"
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Database path: $DB_PATH"
echo "Target level: $LEVEL (Species)"
echo "Read length: $READ_LEN"
echo "=================================================="

# ==============================================================================
# Process all .kreport files in the input directory
# ==============================================================================
for kreport in "$INPUT_DIR"/*.kreport; do
    [ -f "$kreport" ] || continue

    # Extract sample ID (e.g., sample1.kreport -> sample1)
    filename=$(basename "$kreport")
    sample_id="${filename%.kreport}"

    echo -e "\n[$(date +'%Y-%m-%d %H:%M:%S')] Processing sample: ${sample_id} ..."

    out_bracken="$OUTPUT_DIR/${sample_id}.bracken"
    out_kreport="$OUTPUT_DIR/${sample_id}_bracken.kreport"

    # Run Bracken via conda run
    conda run -n kraken2_env bracken -d "$DB_PATH" -i "$kreport" -o "$out_bracken" -w "$out_kreport" -r "$READ_LEN" -l "$LEVEL"

    echo "Sample ${sample_id} finished."
    echo "  - Bracken report: $out_bracken"
    echo "  - Updated kreport: $out_kreport"
done

echo -e "\n=================================================="
echo "All samples finished successfully!"
echo "Results saved in: $OUTPUT_DIR"
echo "=================================================="
