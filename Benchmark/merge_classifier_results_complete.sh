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
    echo "                         Supported formats: centrifuge, kraken, clark, kaiju, auto"
    echo "  -p, --param-extract    Extract parameters from filenames (default: true)"
    echo "                         If enabled, extracts parameters like depth, read length, etc."
    echo "  -d, --debug            Enable debug output (default: false)"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -i 'output/CENTRIFUGE/*.txt' -o results/centrifuge_merged.tsv"
    echo "  $0 -i 'output/KRAKEN/*.txt' -o results/kraken_merged.tsv -c 2 -t 3"
    echo "  $0 -i 'output/CLARK/*.csv' -o results/clark_merged.tsv -f clark"
    echo "  $0 -i 'output/KAIJU/*.out' -o results/kaiju_merged.tsv -f kaiju"
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
DEBUG=false

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
        -d|--debug) DEBUG=true; shift ;;
        -h|--help) show_usage ;;
        *) echo "Unknown parameter: $1"; show_usage ;;
    esac
done

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1"
    fi
}

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
    local skip_lines="$SKIP_LINES"
    
    # Skip autodetection if format and columns are specified
    if [ "$format" != "auto" ] && [ "$count_col" -gt 0 ] && [ "$taxid_col" -gt 0 ]; then
        echo "$format $count_col $taxid_col $skip_lines"
        return
    fi
    
    # Read the first few lines of the file
    local header=$(head -n 20 "$file")
    local first_line=$(head -n 1 "$file")
    
    debug "First line of file: $first_line"
    
    # Try to detect Centrifuge format
    if [ "$format" = "auto" ] && echo "$header" | grep -q "readID"; then
        format="centrifuge"
    fi
    
    # Try to detect Kraken format
    if [ "$format" = "auto" ] && echo "$first_line" | grep -q "^[CUK]"; then
        if ! echo "$first_line" | grep -q "Object_ID" && ! echo "$first_line" | grep -q "Assignment"; then
            format="kraken"
        fi
    fi
    
    # Try to detect CLARK format
    if [ "$format" = "auto" ] && echo "$first_line" | grep -q "Object_ID"; then
        format="clark"
    fi
    
    # Try to detect Kaiju format
    if [ "$format" = "auto" ] && echo "$first_line" | grep -q "^[CU]"; then
        # Make sure it's not CLARK or other format
        if ! echo "$first_line" | grep -q "Object_ID" && ! echo "$first_line" | grep -q "Assignment"; then
            format="kaiju"
        fi
    fi
    
    # If still auto, use the filename/extension as a hint
    if [ "$format" = "auto" ]; then
        if [[ "$file" == *"centrifuge"* ]]; then
            format="centrifuge"
        elif [[ "$file" == *"kraken"* ]]; then
            format="kraken"
        elif [[ "$file" == *"clark"* ]] || [[ "$file" == *".csv" ]]; then
            format="clark"
        elif [[ "$file" == *"kaiju"* ]] || [[ "$file" == *".out" ]]; then
            format="kaiju"
        else
            # Examine file content more closely
            if grep -q "^C\|^U" "$file" && ! grep -q "Object_ID" "$file"; then
                # Looks like Kaiju's format
                format="kaiju"
            elif grep -q "Object_ID" "$file"; then
                # Looks like CLARK's format
                format="clark"
            else
                # Default to centrifuge format as fallback
                format="centrifuge"
            fi
        fi
    fi
    
    debug "Detected format: $format"
    
    # Set columns and skip lines based on format if they weren't specified
    if [ "$format" = "centrifuge" ] && [ "$count_col" -eq 0 ]; then
        # Centrifuge format: readID, seqID, taxID, score, ...
        count_col=1  # readID column is used to count
        taxid_col=3  # taxID is column 3
        skip_lines=1 # Usually has a header line
    elif [ "$format" = "kraken" ] && [ "$count_col" -eq 0 ]; then
        # Kraken format: C/U/K, sequence, taxID, length, LCA mapping
        count_col=1  # Count of sequences
        taxid_col=3  # taxID is column 3
        skip_lines=0 # Usually no header
    elif [ "$format" = "clark" ] && [ "$count_col" -eq 0 ]; then
        # CLARK format: Object_ID, Length, Assignment
        count_col=1  # Count of sequences
        taxid_col=3  # Assignment column (3rd column)
        skip_lines=1 # Has a header line
    elif [ "$format" = "kaiju" ] && [ "$count_col" -eq 0 ]; then
        # Kaiju format: C/U, sequence, taxID, ...
        count_col=1  # Count of sequences
        taxid_col=3  # taxID is typically column 3
        skip_lines=0 # Usually no header
    fi
    
    debug "Format: $format, Count col: $count_col, TaxID col: $taxid_col, Skip lines: $skip_lines"
    
    echo "$format $count_col $taxid_col $skip_lines"
}

# Function to extract parameters from filename
extract_params() {
    local filename="$1"
    local basename=$(basename "$filename")
    local params=""
    
    # Strip common classifier suffixes
    basename=${basename%_centrifuge.txt}
    basename=${basename%_kraken.txt}
    basename=${basename%_clark.txt}
    basename=${basename%_clark.csv}
    basename=${basename%_kaiju.txt}
    basename=${basename%_kaiju.out}
    basename=${basename%_report.txt}
    basename=${basename%_results.txt}
    basename=${basename%.txt}
    basename=${basename%.csv}
    basename=${basename%.out}
    
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
        # Remove trailing semicolon
        echo "${params%;}"
    fi
}

# Detect format of the first file
DETECTED=$(detect_format "${FILES[0]}")
FORMAT=$(echo "$DETECTED" | cut -d' ' -f1)
COUNT_COL=$(echo "$DETECTED" | cut -d' ' -f2)
TAXID_COL=$(echo "$DETECTED" | cut -d' ' -f3)
SKIP_LINES=$(echo "$DETECTED" | cut -d' ' -f4)

echo "Using format: $FORMAT (count column: $COUNT_COL, taxID column: $TAXID_COL, skip lines: $SKIP_LINES)"

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
    case "$FORMAT" in
        "centrifuge")
            # For Centrifuge format
            tail -n +$((SKIP_LINES + 1)) "$file" | \
                awk -v taxcol="$TAXID_COL" '{ tax[$taxcol]++ } END { for (t in tax) print t, tax[t] }' > "${TEMP_DIR}/${sample}.counts"
            ;;
        "kraken")
            # For Kraken format
            tail -n +$((SKIP_LINES + 1)) "$file" | \
                awk -v taxcol="$TAXID_COL" '{ tax[$taxcol]++ } END { for (t in tax) print t, tax[t] }' > "${TEMP_DIR}/${sample}.counts"
            ;;
        "clark")
            # For CLARK format - CSV with Object_ID, Length, Assignment
            tail -n +$((SKIP_LINES + 1)) "$file" | \
                awk -v taxcol="$TAXID_COL" -F", *" '
                { 
                    # Only count assignments that are not NA
                    if ($taxcol != "NA" && length($taxcol) > 0) {
                        tax[$taxcol]++
                    }
                } 
                END { 
                    for (t in tax) print t, tax[t] 
                }' > "${TEMP_DIR}/${sample}.counts"
            ;;
        "kaiju")
            # For Kaiju format - only count classified (C) entries and extract taxid from the third column
            tail -n +$((SKIP_LINES + 1)) "$file" | \
                awk '
                $1 == "C" { 
                    # For classified reads, use the taxid in the appropriate column
                    tax[$3]++ 
                } 
                END { 
                    for (t in tax) print t, tax[t] 
                }' > "${TEMP_DIR}/${sample}.counts"
            ;;
        *)
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
            ;;
    esac
    
    # Check if any taxids were extracted
    if [ ! -s "${TEMP_DIR}/${sample}.counts" ]; then
        echo "Warning: No valid taxonomic assignments found in $filename"
        # Create an empty counts file to avoid errors
        echo "0 0" > "${TEMP_DIR}/${sample}.counts"
    fi
    
    # Add sample to list
    echo "$sample" >> "${TEMP_DIR}/samples.txt"
done

# Collect all unique taxIDs
echo "Collecting unique taxIDs..."
cat "${TEMP_DIR}"/*.counts | awk '{print $1}' | grep -v "^0$" | sort -u > "${TEMP_DIR}/all_taxids.txt"
NUM_TAXIDS=$(wc -l < "${TEMP_DIR}/all_taxids.txt")
echo "Found $NUM_TAXIDS unique taxIDs"

# Create the header line for the output file
echo -e "taxID\t$(paste -s -d '\t' "${TEMP_DIR}/samples.txt")" > "$OUTPUT_FILE"

# Create the merged result table
echo "Merging results..."
while read -r taxid; do
    # Skip taxid 0 (invalid/unassigned)
    if [ "$taxid" == "0" ]; then
        continue
    fi
    
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