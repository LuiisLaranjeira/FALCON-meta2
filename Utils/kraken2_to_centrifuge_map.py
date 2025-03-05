#!/usr/bin/env python3

import sys

"""
Convert a kraken2 seqid2taxid-style file into a centrifuge seqid2taxid.map file.

Usage:
  kraken2_to_centrifuge_map.py <kraken2_map_input> <centrifuge_map_output>

Example kraken2_map_input lines may look like:
  >NZ_AAPH01000079.1 taxid 12345
  >NC_006370.1 taxid 56789
or (depending on the version):
  NZ_AAPH01000079.1   12345
  NC_006370.1         56789

We'll produce lines like:
  NZ_AAPH01000079.1   12345
  NC_006370.1         56789
which Centrifuge requires for --conversion-table.
"""

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <kraken2_map_input> <centrifuge_map_output>", file=sys.stderr)
    sys.exit(1)

kraken2_map_file = sys.argv[1]
centrifuge_map_file = sys.argv[2]

with open(kraken2_map_file, "r") as infile, open(centrifuge_map_file, "w") as outfile:
    for line in infile:
        line = line.strip()
        if not line:
            continue

        # Remove leading '>' if present
        if line.startswith(">"):
            line = line[1:].strip()

        # Split by whitespace
        parts = line.split()

        # Possible patterns:
        #  1) NZ_ABC... taxid 12345   (3 columns)
        #  2) NZ_ABC... 12345        (2 columns)
        # We'll handle both. Lines with unexpected patterns will be skipped.
        if len(parts) == 3 and parts[1].lower() == "taxid":
            seqid = parts[0]
            taxid = parts[2]
        elif len(parts) == 2:
            seqid, taxid = parts
        else:
            # Unrecognized format; log a warning or skip
            print(f"[WARN] Unrecognized line format, skipping: {line}", file=sys.stderr)
            continue

        # Write out the two-column line
        outfile.write(f"{seqid}\t{taxid}\n")
