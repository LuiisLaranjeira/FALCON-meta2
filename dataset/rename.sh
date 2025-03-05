#!/bin/bash
# Usage: ./rename_files.sh <tool_name> [database]
# Example: ./rename_files.sh kraken2 refseq

# Check for at least one argument (tool name)
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <tool_name> [database]"
    exit 1
fi

TOOL_NAME="$1"

# Set default database name if not provided
DATABASE="${2:-default}"

# Expected output pattern: *.${TOOL_NAME}.${DATABASE}.txt
# Loop over all .txt files in the current folder
for file in *.txt; do
    # Check if file already contains the tool name pattern (e.g. ".kraken2.")
    if [[ "$file" != *".${TOOL_NAME}."* ]]; then
        # Get base name by stripping the .txt extension
        base=$(basename "$file" .txt)
        # Construct new filename
        newname="${base}.${TOOL_NAME}.${DATABASE}.txt"
        echo "Renaming '$file' to '$newname'"
        mv "$file" "reports/$newname"
    else
        echo "Skipping '$file' (already matches pattern)"
    fi
done
