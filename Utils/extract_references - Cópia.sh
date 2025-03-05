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
    
    # Check if assemblies exist
    local count=$(esearch -db assembly -query "txid${taxid}[Organism:exp] AND 'complete genome'[filter] AND latest_refseq[filter] AND (latest[filter] AND all[filter] NOT anomalous[filter])" | \
        grep "<Count>" | sed 's/<Count>\([0-9]*\)<\/Count>/\1/')
    
    if [ "$count" -eq 0 ]; then
        echo "No assemblies found for taxid: $taxid"
        return 2
    fi
    
    
    while [ $attempt -le $max_attempts ]; do
        echo "Processing taxid: $taxid (Attempt $attempt/$max_attempts)"
        
        # Get FTP path
        local ftppath=$(esearch -db assembly -query "txid${taxid}[Organism:exp] AND 'complete genome'[filter] AND latest_refseq[filter] AND (latest[filter] AND all[filter] NOT anomalous[filter])" | \
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

# Process the CSV file
while IFS=',' read -r refseq_acc genbank_acc organism taxid; do
    # Skip header
    [[ $refseq_acc == "Refseq accn" ]] && continue
    
    # Clean the taxid (remove any whitespace/quotes)
    taxid=$(echo $taxid | tr -d '"' | tr -d '\r' | tr -d ' ')
    organism=$(echo $organism | tr -d '"' | tr -d '\r')
    
    echo "Processing $organism (taxid: $taxid)"
    download_assembly "$taxid"
    
    # Respect NCBI rate limits
    sleep 2
done < refseq-genbank.csv