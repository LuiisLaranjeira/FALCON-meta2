#!/bin/bash

# Script Name: create_seqid2taxid_map.sh
# Description: Creates a seqid2taxid.map file by mapping sequence accessions to TaxIDs.
#              Skips empty .fna.gz files without headers.
# Usage: ./create_seqid2taxid_map.sh
# Ensure you have execution permissions: chmod +x create_seqid2taxid_map.sh

# Directory containing the .fna.gz files
INPUT_DIR="./downloaded_taxa"  # Adjust the path if necessary

# Output mapping file
OUTPUT_MAP="../seqid2taxid.map"  # Placing it in the parent directory

# Initialize (create or empty) the output file
> "$OUTPUT_MAP"

# Check if INPUT_DIR exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Navigate to the input directory
cd "$INPUT_DIR" || { echo "Failed to enter directory '$INPUT_DIR'."; exit 1; }

# Iterate over each .fna.gz file
for file in *.fna.gz; do
    # Check if any .fna.gz files exist
    if [ "$file" == "*.fna.gz" ]; then
        echo "No .fna.gz files found in '$INPUT_DIR'."
        break
    fi

    # Extract TaxID from filename (e.g., 10015 from 10015.fna.gz)
    taxid="${file%%.fna.gz}"

    # Inform the user about the current file being processed
    echo "Processing TaxID: $taxid from file: $file"

    # Extract headers, remove '>', get the first word (accession)
    # and check if there are any headers
    headers=$(zgrep '^>' "$file" 2>/dev/null)

    if [ -z "$headers" ]; then
        echo "Warning: No headers found in '$file'. Skipping."
        continue  # Skip to the next file
    fi

    # Process headers and append to the mapping file
    echo "$headers" | \
    sed 's/^>//' | \
    awk -v taxid="$taxid" '{print $1 "\t" taxid}' >> "$OUTPUT_MAP"

    # Optional: Inform the user about completion of the current file
    echo "Mapped accessions from $file to TaxID $taxid."
done

# Navigate back to the original directory
cd - > /dev/null || exit

# Final message
echo "Mapping complete. See '$OUTPUT_MAP'."
