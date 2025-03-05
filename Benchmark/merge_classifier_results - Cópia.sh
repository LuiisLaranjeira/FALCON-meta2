#!/bin/bash
# merge_classifier_results.sh - Merge individual classifier outputs into a single table
#
# Usage: ./merge_classifier_results.sh <classifier_name> <output_dir> <output_file>

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <classifier_name> <output_dir> <output_file>"
    echo "Example: $0 CENTRIFUGE ./DNA/output results/CENTRIFUGE_merged.tsv"
    exit 1
fi

CLASSIFIER=$1
OUTPUT_DIR=$2
OUTPUT_FILE=$3

# Create output directory if it doesn't exist
mkdir -p $(dirname "$OUTPUT_FILE")

echo "Merging results for classifier: $CLASSIFIER"

# Find all ReadspTaxon.txt files for this classifier
TAXON_FILES=$(find "${OUTPUT_DIR}/${CLASSIFIER}" -name "*_ReadspTaxon.txt" 2>/dev/null)

if [ -z "$TAXON_FILES" ]; then
    echo "No taxonomy files found for $CLASSIFIER in ${OUTPUT_DIR}/${CLASSIFIER}"
    exit 1
fi

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Process each file and extract sample name
echo "Processing $(echo "$TAXON_FILES" | wc -l) files..."

# Initialize an empty headers file
echo -e "taxID" > "${TEMP_DIR}/headers.txt"

# Process each file
for FILE in $TAXON_FILES; do
    # Extract sample name from the file path
    SAMPLE=$(basename "$(dirname "$FILE")")
    
    # Check if file is empty
    if [ ! -s "$FILE" ]; then
        echo "Skipping empty file: $FILE"
        continue
    fi
    
    # Extract TaxID and count, add sample name as column
    awk -v sample="$SAMPLE" '{print $2 "\t" $1}' "$FILE" > "${TEMP_DIR}/${SAMPLE}.tmp"
    
    # Add sample name to headers
    echo -e "$SAMPLE" >> "${TEMP_DIR}/headers.txt"
done

# Create a final merged file
echo "Merging results..."

# Get unique TaxIDs from all files
cat "${TEMP_DIR}"/*.tmp | cut -f1 | sort -u > "${TEMP_DIR}/all_taxids.txt"

# Create header row
paste -s "${TEMP_DIR}/headers.txt" > "$OUTPUT_FILE"

# For each unique TaxID
while read TAXID; do
    # Start a new line with the TaxID
    echo -n "$TAXID" > "${TEMP_DIR}/current_line.txt"
    
    # Add count for each sample (0 if not found)
    for FILE in "${TEMP_DIR}"/*.tmp; do
        SAMPLE=$(basename "$FILE" .tmp)
        
        # Get count for this TaxID in this sample (0 if not found)
        COUNT=$(grep -w "^$TAXID" "$FILE" | cut -f2 || echo "0")
        
        # If empty, set to 0
        if [ -z "$COUNT" ]; then
            COUNT="0"
        fi
        
        # Append to the current line
        echo -n -e "\t$COUNT" >> "${TEMP_DIR}/current_line.txt"
    done
    
    # Add the line to the output file
    cat "${TEMP_DIR}/current_line.txt" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
done < "${TEMP_DIR}/all_taxids.txt"

# Count entries
NUM_TAXIDS=$(wc -l < "${TEMP_DIR}/all_taxids.txt")
NUM_SAMPLES=$(($(cat "${TEMP_DIR}/headers.txt" | wc -l) - 1))

echo "Merged $NUM_SAMPLES samples with $NUM_TAXIDS unique TaxIDs"
echo "Results saved to $OUTPUT_FILE"