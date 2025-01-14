#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# safe_zcat.sh
#
# Description:
#   - Reads all .fna.gz files in a specified directory (or all *.gz
#     in the current directory) one by one.
#   - Verifies each file is non-empty and uncorrupted (via gunzip -t).
#   - Appends the valid file contents to a single combined FASTA
#     output file (uncompressed).
#   - Skips or removes any corrupted files, logging an error message.
# ------------------------------------------------------------------

# Directory containing .fna.gz files
INPUT_DIR="downloaded_taxa"

# Output file for combined (uncompressed) FASTA
OUTPUT_FASTA="all_sequences.fna"

# 1) Ensure output file doesn’t already exist or remove old version
rm -f "${OUTPUT_FASTA}"

# 2) Loop over all .fna.gz files in INPUT_DIR
for gzfile in "${INPUT_DIR}"/*.fna.gz; do
    # Skip if there are no .fna.gz files
    if [[ ! -f "$gzfile" ]]; then
        echo "[WARN] No .fna.gz files found in ${INPUT_DIR}"
        break
    fi

    # Check that file is non-empty
    if [[ ! -s "$gzfile" ]]; then
        echo "[ERROR] ${gzfile} is empty, skipping..."
        continue
    fi

    # Check gzip integrity
    if ! gunzip -t "$gzfile" 2>/dev/null; then
        echo "[ERROR] ${gzfile} is corrupted! Removing file..."
        rm -f "$gzfile"
        continue
    fi

    # If we reach here, file is valid. Append to the output using zcat.
    echo "[INFO] Appending ${gzfile} to ${OUTPUT_FASTA}..."
    zcat "${gzfile}" >> "${OUTPUT_FASTA}"
done

# Final check
if [[ -f "${OUTPUT_FASTA}" ]]; then
    echo "[INFO] Successfully created combined FASTA: ${OUTPUT_FASTA}"
else
    echo "[WARN] No valid .fna.gz files were processed."
fi
