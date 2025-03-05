


$query = $organism.'[orgn] AND srcdb_refseq[prop]';

$
esearch -db assembly -query "viruses[ORGN] AND srcdb_refseq[prop]" 

organism="viruses"
# srcdb_refseq[prop] ensures we only get RefSeq sequences
query="${organism}[orgn] AND srcdb_refseq[prop]"
subquery="${organism}[Organism] AND 'complete genome'[filter] AND latest_refseq[filter] AND (latest[filter] NOT anomalous[filter])"


echo "Searching RefSeq for '${organism}' using query: ${query}"

OUTPUT_DIR="${organism}"

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

esearch -db assembly \
  -query $query
  > vir_search.xml


cat ${organism}_search.xml \
| esummary -db assembly \
> ${organism}_summary.xml



cat ${organism}_summary.xml \
| xtract -pattern DocumentSummary \
    -element AssemblyAccession \
    -element OrgName \
    -element FtpPath_RefSeq \
    -element TotalSequenceLength \
> ${organism}_vir.tsv


sort -k4,4n ${organism}_vir.tsv > ${organism}_sorted.tsv


while IFS=$'\t' read -r acc org ftp size; do
  # The FASTA file is typically named like GCF_00012345.1_XXXX_genomic.fna.gz
  # We'll just use a wildcard to match that file:
  wget -q -P $OUTPUT_DIR "${ftp}/*_genomic.fna.gz"
done < ${organism}_sorted.tsv


 esearch -db assembly -query "viruses[Organism] AND 'complete genome'[filter] AND latest_refseq[filter] AND (representative[filter] NOT anomalous[filter])"



local search_query="${organism}[ORGN] AND srcdb_refseq[prop]"

#!/bin/bash

set -eu

OUTPUT_DIR="reference_genomes"
TIMESTAMP=$(date +"%Y%m%d")
MAX_SEQUENCES=100
EMAIL=""

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

download_genomes() {
    local group="$1"
    local output_file="${TIMESTAMP}_${group}_genomes.fasta"
    
    echo "Downloading $group genomes..."
    
    local search_query="(${group}[Organism] AND srcdb refseq[properties]) AND (complete genome[title] OR whole genome shotgun sequence[title])"
    
    esearch -db nucleotide -query "$search_query" ${EMAIL:+ -email "$EMAIL"} | \
    efetch -format fasta -stop "$MAX_SEQUENCES" > "$output_file" 2>download_error.log
    
    if [ -f "$output_file" ]; then
        local seq_count
        seq_count=$(grep -c ">" "$output_file" 2>/dev/null || echo "0")
        echo "Downloaded ${seq_count} sequences for $group"
        return 0
    else
        echo "No output file created for $group"
        return 1
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <group_name>"
    exit 1
fi

download_genomes "$1"