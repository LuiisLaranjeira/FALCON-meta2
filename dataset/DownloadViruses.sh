#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: ./download_organism.sh [organism]
# Example: ./download_organism.sh bacteria
# If no argument is given, defaults to 'viruses'.

## (Plan Step 1) ESearch
organism="${1:-viruses}"
##query="${organism}[ORGN] AND srcdb_refseq[prop]"
query="${organism}[Organism] AND 'complete genome'[filter] AND latest_refseq[filter] AND (latest[filter] NOT anomalous[filter])"
echo "Querying assembly DB for: $query"

mkdir -p "$organism"
cd "$organism"

esearch -db assembly -query "$query" > "${organism}_search.xml"

## (Plan Step 2) ESummary + xtract
cat "${organism}_search.xml" \
  | esummary -db assembly \
  > "${organism}_summary.xml"

cat "${organism}_summary.xml" \
  | xtract -pattern DocumentSummary \
      -element AssemblyAccession \
               OrgName \
               FtpPath_RefSeq \
               TotalSequenceLength \
  > "${organism}.tsv"

sort -k4,4n "${organism}.tsv" > "${organism}_sorted.tsv"

## (Plan Step 3) Download FASTA
output_dir="reference_fastas"
mkdir -p "$output_dir"

echo "Starting downloads..."
while IFS=$'\t' read -r acc org ftp size; do
  if [[ -n "$ftp" ]]; then
    # Each assembly directory typically has a file ending in "_genomic.fna.gz"
    wget -q -P "$output_dir" "${ftp}/*_genomic.fna.gz"
  fi
done < "${organism}_sorted.tsv"

echo "All downloads complete."
echo "Files saved in: ${organism}/${output_dir}"
