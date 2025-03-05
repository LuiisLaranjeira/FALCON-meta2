#!/bin/bash

# Check if database name is provided
if [ -z "$DBNAME" ]; then
    echo "Error: Database name not set. Please set DBNAME environment variable."
    exit 1
fi

# Check if directory exists
if [ ! -d "/downloaded_taxa" ]; then
    echo "Error: Directory /downloaded_taxa not found"
    exit 1
fi

# Check if any matching files exist
if [ ! "$(ls -A /downloaded_taxa/*.fna.gz 2>/dev/null)" ]; then
    echo "Error: No .fna.gz files found in /downloaded_taxa"
    exit 1
fi

# Process files
for file in /downloaded_taxa/*.fna.gz
do
    echo "Processing $file..."
    if ! kraken2-build --add-to-library "$file" --db "$DBNAME"; then
        echo "Error processing $file"
        exit 1
    fi
done

echo "All files processed successfully"