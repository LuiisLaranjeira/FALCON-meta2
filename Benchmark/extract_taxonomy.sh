#!/bin/bash
# extract_taxonomy.sh - Extract taxonomy information from database FASTA files
#
# Usage: ./extract_taxonomy.sh -i <database_pattern> [-i <database_pattern2> ...] -o <output_file>

set -e  # Exit on error

show_usage() {
    echo "Usage: $0 -i <database_pattern> [-i <database_pattern2> ...] -o <output_file>"
    echo "Examples:"
    echo "  $0 -i /path/to/db.fasta -o taxonomy.tsv"
    echo "  $0 -i '/path/db/*.fasta' -o taxonomy.tsv"
    exit 1
}

# Parse arguments
PATTERNS=()
OUTPUT_FILE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--input) PATTERNS+=("$2"); shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; show_usage ;;
    esac
done

# Validate arguments
if [ ${#PATTERNS[@]} -eq 0 ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Missing required arguments"
    show_usage
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Create output file with headers
echo -e "TaxID\tAccession\tOrganism\tSource" > "$OUTPUT_FILE"

# Track statistics
total_files=0
total_sequences=0

# Process each pattern
for pattern in "${PATTERNS[@]}"; do
    # Expand pattern to files
    for file in $(eval echo "$pattern"); do
        if [[ ! -f "$file" ]]; then
            echo "Warning: '$file' not found or not a file. Skipping."
            continue
        fi
        
        # Check if it looks like a FASTA file (first character is >)
        first_char=$(head -c 1 "$file")
        if [[ "$first_char" != ">" ]]; then
            echo "Warning: '$file' doesn't appear to be a FASTA file. Skipping."
            continue
        fi
        
        total_files=$((total_files + 1))
        db_name=$(basename "$file" | sed 's/\.[^.]*$//')
        echo "Processing $file..."
        
        # Process the FASTA file - extract header lines only
        sequence_count=0
        
        while IFS= read -r line; do
            # Process only header lines
            if [[ ${line:0:1} == ">" ]]; then
                sequence_count=$((sequence_count + 1))
                header=${line:1}  # Remove the '>' character
                
                # Extract TaxID - look for common patterns
                taxid="Unknown"
                if [[ "$header" =~ taxid[|:]([0-9]+) ]]; then
                    taxid="${BASH_REMATCH[1]}"
                elif [[ "$header" =~ \|([0-9]+)\| ]]; then
                    taxid="${BASH_REMATCH[1]}"
                fi
                
                # Extract accession - usually the first word after potential taxid info
                accession="Unknown"
                # First try to match common NCBI accession format
                if [[ "$header" =~ [^[:alnum:]]?([A-Z]{1,2}_[0-9]+\.[0-9]+) ]]; then
                    accession="${BASH_REMATCH[1]}"
                else
                    # Otherwise use the first word
                    accession=$(echo "$header" | awk '{print $1}')
                    # Remove taxid prefix if present
                    accession=$(echo "$accession" | sed 's/^.*taxid[|:][0-9]*[[:space:]]*//g')
                fi
                
                # Extract organism name - everything after accession until first comma
                organism=$(echo "$header" | sed -E "s/^.*$accession[[:space:]]*(.*)/\1/")
                # Get text up to first comma if there is one
                if [[ "$organism" == *","* ]]; then
                    organism="${organism%%,*}"
                fi
                
                # Output to file
                echo -e "$taxid\t$accession\t$organism\t$db_name" >> "$OUTPUT_FILE"
            fi
        done < "$file"
        
        echo "  Processed $sequence_count sequences from $file"
        total_sequences=$((total_sequences + sequence_count))
    done
done

# Summary
echo
echo "=== Summary ==="
echo "Processed $total_files FASTA files"
echo "Extracted taxonomy information for $total_sequences sequences"
echo "Results saved to $OUTPUT_FILE"