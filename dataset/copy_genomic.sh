#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# copy_genomic.sh
#
# Usage:
#   ./copy_genomic.sh /path/to/src /path/to/dest
#
# Description:
#   - Copies only files ending with "_genomic.fna.gz" from src to dest
#   - Excludes files if they contain "_rna_from_" or "_cds_from_"
###############################################################################

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <src_dir> <dst_dir>"
  exit 1
fi

src_dir="$1"
dst_dir="$2"

mkdir -p "$dst_dir"

# Loop over files ending with "_genomic.fna.gz"
for f in "$src_dir"/*_genomic.fna.gz; do
  # If file doesn't exist (e.g., no matches), skip
  [[ ! -e "$f" ]] && continue

  # Exclude if filename contains "_rna_from_" or "_cds_from_"
  case "$f" in
    *_rna_from_*|*_cds_from_*)
      echo "Skipping: $f"
      continue
      ;;
  esac

  # Otherwise, copy
  echo "Copying: $f"
  cp "$f" "$dst_dir"/
done

echo "Done!"
