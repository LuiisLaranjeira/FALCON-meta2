#!/bin/bash

set -eu

DOWNLOAD_GROUPS=("bacteria" "viral" "archaea" "fungi")
MAX_SEQUENCES=1000
OUTPUT_DIR="reference_genomes"
TIMESTAMP=$(date +"%Y%m%d")

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

download_genomes() {
    local group="$1"
    local output_file="${TIMESTAMP}_${group}.fasta"
    
    echo "Downloading $group reference genomes..."
    
    # NCBI Entrez query with proper syntax
    esearch -db nucleotide \
        -query "${group}[ORGN] AND biomol_genomic[PROP] AND refseq[filter]" \
        -use_history y | \
    efetch -format fasta > "$output_file"
    
    if [ -f "$output_file" ]; then
        local seq_count=$(grep -c ">" "$output_file" 2>/dev/null || echo "0")
        echo "Downloaded ${seq_count} sequences for $group"
        return 0
    fi
    return 1
}

for group in "${DOWNLOAD_GROUPS[@]}"; do
    download_genomes "$group"
done