#!/usr/bin/env bash

# Directory containing kaiju output files
KAJU_OUT_DIR="output/KAIJU"

# Kaiju nodes and names files
NODES="kaiju/nodes.dmp"
NAMES="kaiju/names.dmp"

# Output directory for reports
REPORTS_DIR="reports_output/KAIJU"

# Create the reports directory if it doesn't exist
mkdir -p "${REPORTS_DIR}"

# Loop over each Kaiju output file in KAJU_OUT_DIR
for FILE in "${KAJU_OUT_DIR}"/*.txt; do
  
  # Extract the filename without the directory and extension
  BASENAME=$(basename "${FILE}" .txt)
  
  # Construct the output report filename
  REPORT_FILE="${REPORTS_DIR}/${BASENAME}_report.txt"
  
  # Run kaiju2table
  kaiju2table \
    -t "${NODES}" \
    -n "${NAMES}" \
    -r species \
    -o "${REPORT_FILE}" \
    "${FILE}"
    
  echo "Generated report: ${REPORT_FILE}"
done
