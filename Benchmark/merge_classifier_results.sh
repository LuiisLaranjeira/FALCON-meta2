#!/bin/bash
# merge_classifier_results.sh - Merge classifier outputs into a single table
#
# Usage: ./merge_classifier_results.sh -i <input_pattern> -o <output_file> [options]

set -e  # Exit on error

show_usage() {
    echo "Usage: $0 -i <input_pattern> -o <output_file> [options]"
    echo
    echo "Required arguments:"
    echo "  -i, --input PATTERN    File pattern for input files (e.g., '/path/to/CENTRIFUGE/*.txt')"
    echo "  -o, --output FILE      Output file path for merged results"
    echo
    echo "Optional arguments:"
    echo "  -c, --count-col NUM    Column number containing counts (default: autodetect)"
    echo "  -t, --taxid-col NUM    Column number containing taxIDs (default: autodetect)"
    echo "  -s, --skip-lines NUM   Number of header lines to skip (default: 0)"
    echo "  -f, --format FORMAT    Format of the result files (default: autodetect)"
    echo "                         Supported formats: centrifuge, kraken, auto"
    echo "  -p, --param-extract    Extract parameters from filenames (default: true)"
    echo "                         If enabled, extracts parameters like depth, read length, etc."
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -i 'output/CENTRIFUGE/*.txt' -o results/centrifuge_merged.tsv"
    echo "  $0 -i 'output/KRAKEN/*.txt' -o results/kraken_merged.tsv -c 2 -t 3"
    exit 1
}

# Default values
INPUT_PATTERN=""
OUTPUT_FILE=""
COUNT_COL=0  # 0 means autodetect
TAXID_COL=0  # 0 means autodetect
SKIP_LINES=0
FORMAT="auto"
PARAM_EXTRACT=true

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--input) INPUT_PATTERN="$2"; shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -c|--count-col) COUNT_COL="$2"; shift 2 ;;
        -t|--taxid-col) TAXID_COL="$2"; shift 2 ;;
        -s|--skip-lines) SKIP_LINES="$2"; shift 2 ;;
        -f|--format) FORMAT="$2"; shift 2 ;;
        -p|--param-extract) PARAM_EXTRACT="$2"; shift 2 ;;
        -h|--help) show_usage ;;
        *) echo "Unknown parameter: $1"; show_usage ;;
    esac
done

# Validate arguments
if [ -z "$INPUT_PATTERN" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Missing required arguments"
    show_usage
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Expand the input pattern to get file list
FILES=($(eval echo "$INPUT_PATTERN"))

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No files found matching pattern: $INPUT_PATTERN"
    exit 1
fi

echo "Found ${#FILES[@]} files to process"

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Function to detect file format and columns
detect_format() {
    local file="$1"
    local format="$FORMAT"
    local count_col="$COUNT_COL"
    local taxid_col="$TAXID_COL"
    
    # Skip autodetection if format and columns are specified
    if [ "$format" != "auto" ] && [ "$count_col" -gt 0 ] && [ "$taxid_col" -gt 0 ]; then
        echo "$format $count_col $taxid_col"
        return
    fi
    
    # Read the first few lines of the file
    local header=$(head -n 10 "$file")
    
    # Try to detect Centrifuge format
    if [ "$format" = "auto" ] && echo "$header" | grep -q "readID"; then
        format="centrifuge"
    fi
    
    # Try to detect Kraken format
    if [ "$format" = "auto" ] && echo "$header" | grep -q "C\|U\|K"; then
        format="kraken"
    fi
    
    # If still auto, use the filename as a hint
    if [ "$format" = "auto" ]; then
        if [[ "$file" == *"centrifuge"* ]]; then
            format="centrifuge"
        elif [[ "$file" == *"kraken"* ]]; then
            format="kraken"
        else
            # Default to centrifuge format
            format="centrifuge"
        fi
    fi
    
    # Set columns based on format if they weren't specified
    if [ "$format" = "centrifuge" ] && [ "$count_col" -eq 0 ]; then
        # Centrifuge format: readID, seqID, taxID, score, ...
        count_col=1  # readID column is used to count
        taxid_col=3  # taxID is column 3
    elif [ "$format" = "kraken" ] && [ "$count_col" -eq 0 ]; then
        # Kraken format: C/U/K, sequence, taxID, length, LCA mapping
        count_col=1  # Count of sequences
        taxid_col=3  # taxID is column 3
    fi
    
    echo "$format $count_col $taxid_col"
}

# Function to extract parameters from filename
extract_params() {
    local filename="$1"
    local basename=$(basename "$filename")
    local params=""
    
    # Strip common classifier suffixes
    basename=${basename%_centrifuge.txt}
    basename=${basename%_kraken.txt}
    basename=${basename%_report.txt}
    basename=${basename%.txt}
    
    # Extract common parameters from filename
    if [[ "$basename" =~ depth([0-9]+) ]]; then
        params="${params}depth=${BASH_REMATCH[1]};"
    fi
    
    if [[ "$basename" =~ read([0-9]+) ]]; then
        params="${params}read=${BASH_REMATCH[1]};"
    fi
    
    if [[ "$basename" =~ deam([0-9.]+) ]]; then
        params="${params}deam=${BASH_REMATCH[1]};"
    fi
    
    # If no parameters were extracted, use the basename
    if [ -z "$params" ]; then
        echo "$basename"
    else
        echo "$params"
    fi
}

# Detect format of the first file
DETECTED=$(detect_format "${FILES[0]}")
FORMAT=$(echo "$DETECTED" | cut -d' ' -f1)
COUNT_COL=$(echo "$DETECTED" | cut -d' ' -f2)
TAXID_COL=$(echo "$DETECTED" | cut -d' ' -f3)

echo "Using format: $FORMAT (count column: $COUNT_COL, taxID column: $TAXID_COL)"

# Process each file to extract taxID and counts
for file in "${FILES[@]}"; do
    filename=$(basename "$file")
    
    # Extract sample name/parameters from filename
    if [ "$PARAM_EXTRACT" = true ]; then
        sample=$(extract_params "$file")
    else
        sample="${filename%.*}"  # Remove extension
    fi
    
    echo "Processing $filename as sample: $sample"
    
    # Process file based on detected format
    if [ "$FORMAT" = "centrifuge" ]; then
        # For Centrifuge format
        # Skip header lines
        tail -n +$((SKIP_LINES + 1)) "$file" | \
            # Extract taxID and readID, count unique readIDs per taxID
            awk -v taxcol="$TAXID_COL" '{ tax[$taxcol]++ } END { for (t in tax) print t, tax[t] }' > "${TEMP_DIR}/${sample}.counts"
    elif [ "$FORMAT" = "kraken" ]; then
        # For Kraken format
        tail -n +$((SKIP_LINES + 1)) "$file" | \
            awk -v taxcol="$TAXID_COL" '{ tax[$taxcol]++ } END { for (t in tax) print t, tax[t] }' > "${TEMP_DIR}/${sample}.counts"
    else
        # Generic approach - simply count occurrences of each taxID
        tail -n +$((SKIP_LINES + 1)) "$file" | \
            awk -v taxcol="$TAXID_COL" -v countcol="$COUNT_COL" '
            { 
                if (countcol == 1) {
                    # If count column is 1, we just count rows
                    tax[$taxcol]++ 
                } else {
                    # Otherwise sum up the values in count column
                    tax[$taxcol] += $countcol
                }
            } 
            END { 
                for (t in tax) print t, tax[t] 
            }' > "${TEMP_DIR}/${sample}.counts"
    fi
    
    # Add sample to list
    echo "$sample" >> "${TEMP_DIR}/samples.txt"
done

# Collect all unique taxIDs
echo "Collecting unique taxIDs..."
cat "${TEMP_DIR}"/*.counts | awk '{print $1}' | sort -u > "${TEMP_DIR}/all_taxids.txt"
NUM_TAXIDS=$(wc -l < "${TEMP_DIR}/all_taxids.txt")
echo "Found $NUM_TAXIDS unique taxIDs"

# Create the header line for the output file
echo -e "taxID\t$(paste -s -d '\t' "${TEMP_DIR}/samples.txt")" > "$OUTPUT_FILE"

# Create the merged result table
echo "Merging results..."
while read -r taxid; do
    # Start line with taxID
    line="$taxid"
    
    # Add count for each sample (0 if not found)
    while read -r sample; do
        count=$(grep -w "^$taxid" "${TEMP_DIR}/${sample}.counts" 2>/dev/null | awk '{print $2}' || echo "0")
        line="$line\t$count"
    done < "${TEMP_DIR}/samples.txt"
    
    # Add to output file
    echo -e "$line" >> "$OUTPUT_FILE"
done < "${TEMP_DIR}/all_taxids.txt"

# Summary
echo
echo "=== Summary ==="
echo "Processed ${#FILES[@]} input files"
echo "Found $NUM_TAXIDS unique taxIDs"
NUM_SAMPLES=$(wc -l < "${TEMP_DIR}/samples.txt")
echo "Merged data for $NUM_SAMPLES samples"
echo "Results saved to $OUTPUT_FILE"