#!/usr/bin/env bash
set -euo pipefail

########################################
# User-configurable variables
########################################

# Path to your Kraken2 database
KRAKEN_DB="small_kraken2_db"

# Number of parallel jobs for downloading
PARALLEL_JOBS=4

# Output directory for reconstructed genomes
OUTPUT_DIR="reconstructed_genomes_parallel"

########################################
# 1. Inspect the Kraken2 database
########################################

echo "[INFO] Inspecting Kraken2 database: ${KRAKEN_DB}"
kraken2-inspect --db "${KRAKEN_DB}" --show-accs > db_inspect_output.txt

########################################
# 2. Extract unique accession numbers
########################################

echo "[INFO] Extracting accession numbers"
grep '^>' db_inspect_output.txt | sed 's/^>//' > accession_list.txt

echo "[INFO] Deduplicating accession list"
sort accession_list.txt | uniq > accession_list_unique.txt

echo "[INFO] Number of unique accession IDs found:"
wc -l accession_list_unique.txt

########################################
# 3. Create output directory
########################################

mkdir -p "${OUTPUT_DIR}"

########################################
# 4. Download genomes in parallel
########################################

echo "[INFO] Downloading genomes in parallel (${PARALLEL_JOBS} jobs)..."
echo "[INFO] Each genome is stored in an individual gzipped FASTA file."

# 
# Using 'parallel' to fetch each accession:
# - The placeholder '{}' represents each line (accession) from the input file.
# - We pipe it to efetch, requesting FASTA format, then gzip-compress the output.
# - Finally, we write it to a file named after the accession: ${ACC}.fna.gz
#
cat accession_list_unique.txt | parallel -j "${PARALLEL_JOBS}" --progress --eta '
    efetch -db nucleotide -id {} -format fasta |
    gzip -c > "'"${OUTPUT_DIR}"'"/{}.fna.gz
'

########################################
# Done
########################################

echo "[INFO] Download and compression complete."
echo "[INFO] Reconstructed genomes stored in: ${OUTPUT_DIR}"
