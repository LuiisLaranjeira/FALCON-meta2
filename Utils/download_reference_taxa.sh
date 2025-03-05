#!/bin/bash

# Set error handling
set -e
set -u
set -o pipefail

echo "Starting reference extraction at $(date)"

# Function to download assembly
download_assembly() {
    local taxid=$1
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        echo "Processing taxid: $taxid (Attempt $attempt/$max_attempts)"
        
        # Get FTP path
        local ftppath=$(esearch -db assembly -query "taxid$taxid[Organism] AND (latest[Filter] OR reference[Filter])" | \
            efetch -format docsum | \
            xtract -pattern DocumentSummary -element FtpPath_RefSeq | \
            head -n 1)
        
        if [ ! -z "$ftppath" ]; then
            local basename=$(basename $ftppath)
            local target_file="reference_fastas/${basename}_genomic.fna.gz"
            
            if [ ! -f "$target_file" ]; then
                echo "Downloading: $ftppath/${basename}_genomic.fna.gz"
                if wget -q "$ftppath/${basename}_genomic.fna.gz" -P reference_fastas/; then
                    echo "Successfully downloaded: $target_file"
                    return 0
                else
                    echo "Failed to download: $target_file"
                fi
            else
                echo "File already exists: $target_file"
                return 0
            fi
        else
            echo "No FTP path found for taxid: $taxid"
        fi
        
        attempt=$((attempt + 1))
        sleep 5
    done
    
    echo "Failed to download assembly for taxid: $taxid after $max_attempts attempts"
    return 1
}

# Download species assemblies
echo "Downloading species assemblies..."
total_species=$(wc -l < species_taxids.txt)
current=0

while read taxid; do
    current=$((current + 1))
    echo "Processing species $current/$total_species"
    download_assembly "$taxid"
done < species_taxids.txt

# Calculate total size
total_size=$(du -sh reference_fastas | cut -f1)
echo "Total size of downloaded references: $total_size"

# Generate summary
echo "Generating summary..."
echo "Download Summary" > download_summary.txt
echo "Date: $(date)" >> download_summary.txt
echo "Total species processed: $total_species" >> download_summary.txt
echo "Total size: $total_size" >> download_summary.txt
echo "Downloaded files:" >> download_summary.txt
ls -lh reference_fastas >> download_summary.txt

echo "Process completed at $(date)"
echo "See download_summary.txt for download summary"