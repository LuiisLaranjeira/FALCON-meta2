#!/usr/bin/env python3
import sys
import subprocess

"""
Usage:
  fasta2seqid2taxid.py <input_fasta> <output_map>

Description:
  - Reads <input_fasta>, looks for lines starting with '>'.
  - Extracts the sequence ID (accession) up to the first whitespace.
  - Calls "esearch -db taxonomy -query <accession>[ACCN]" and uses "xtract"
    to extract the TaxID.
  - Writes a two-column map file in <output_map>:
      <sequence_id>\t<taxid>
"""

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <input_fasta> <output_map>", file=sys.stderr)
    sys.exit(1)

input_fasta = sys.argv[1]
output_map  = sys.argv[2]

# Open output file
with open(output_map, "w") as out_map:
    # Read the FASTA
    with open(input_fasta, "r") as f:
        for line in f:
            line = line.strip()
            # If it's a FASTA header
            if line.startswith(">"):
                # Extract sequence ID (up to first whitespace)
                seq_id = line[1:].split()[0]

                # Construct a query for NCBI taxonomy
                query = f"{seq_id}[ACCN]"

                # 1) esearch to get the record
                try:
                    esearch_cmd = ["esearch", "-db", "taxonomy", "-query", query]
                    esearch_proc = subprocess.run(
                        esearch_cmd,
                        capture_output=True,
                        text=True,
                        check=True
                    )
                except subprocess.CalledProcessError as e:
                    print(f"[ERROR] esearch failed for {seq_id}: {e}", file=sys.stderr)
                    # Assign taxid=0 if we can't find it
                    out_map.write(f"{seq_id}\t0\n")
                    continue

                # 2) xtract the <Id> field from esearch output
                #    For taxonomy, the <Id> element is the numeric TaxID
                try:
                    xtract_cmd = ["xtract", "-pattern", "Id", "-element", "Id"]
                    xtract_proc = subprocess.run(
                        xtract_cmd,
                        input=esearch_proc.stdout,
                        capture_output=True,
                        text=True,
                        check=True
                    )
                    taxid = xtract_proc.stdout.strip()
                except subprocess.CalledProcessError as e:
                    print(f"[ERROR] xtract failed for {seq_id}: {e}", file=sys.stderr)
                    out_map.write(f"{seq_id}\t0\n")
                    continue

                # If taxid is empty, fallback to 0 or skip
                if not taxid:
                    taxid = "0"

                # Write out the mapping line
                out_map.write(f"{seq_id}\t{taxid}\n")
