import struct
import sys
from collections import defaultdict

def read_opts_k2d(filename):
    """Read and decode opts.k2d file"""
    with open(filename, 'rb') as f:
        data = f.read()
        # First 8 bytes contain k-mer length
        kmer_len = struct.unpack('Q', data[0:8])[0]
        # Next 8 bytes contain minimizer length
        min_len = struct.unpack('Q', data[8:16])[0]
        
        print(f"K-mer length: {kmer_len}")
        print(f"Minimizer length: {min_len}")
        print(f"Total file size: {len(data)} bytes")
        
        # Print raw hex for analysis
        print("\nRaw hex dump:")
        for i in range(0, len(data), 16):
            hex_vals = ' '.join(f'{b:02x}' for b in data[i:i+16])
            print(f"{i:08x}: {hex_vals}")

def read_taxo_k2d(filename):
    """Read and decode taxo.k2d file"""
    tax_ids = set()
    parent_child = defaultdict(list)
    
    with open(filename, 'rb') as f:
        data = f.read()
        # Try to extract taxonomy IDs (usually 4 or 8 byte integers)
        for i in range(0, len(data)-8, 8):
            try:
                tax_id = struct.unpack('Q', data[i:i+8])[0]
                if 0 < tax_id < 2000000:  # Reasonable range for tax IDs
                    tax_ids.add(tax_id)
                    
                    # Try to find parent-child relationships
                    if i + 16 <= len(data):
                        possible_parent = struct.unpack('Q', data[i+8:i+16])[0]
                        if 0 < possible_parent < 2000000:
                            parent_child[possible_parent].append(tax_id)
                            
            except struct.error:
                continue
    
    print(f"\nFound {len(tax_ids)} potential taxonomy IDs")
    print(f"Found {len(parent_child)} potential parent-child relationships")
    
    # Print some example tax IDs
    print("\nSample taxonomy IDs:")
    for tax_id in list(tax_ids)[:10]:
        print(tax_id)
    
    return tax_ids, parent_child

def peek_hash_k2d(filename, chunk_size=1024*1024):
    """Peek into hash.k2d file to try to identify patterns"""
    patterns = defaultdict(int)
    sequence_markers = set()
    
    with open(filename, 'rb') as f:
        # Read first chunk
        data = f.read(chunk_size)
        
        # Look for common sequence patterns
        for i in range(len(data)-8):
            # Look for 8-byte patterns
            pattern = data[i:i+8]
            patterns[pattern] += 1
            
            # Try to decode as potential taxonomy ID
            try:
                value = struct.unpack('Q', pattern)[0]
                if 0 < value < 2000000:  # Reasonable range for tax IDs
                    sequence_markers.add(value)
            except struct.error:
                continue
    
    print(f"\nAnalyzed first {chunk_size/1024/1024:.2f}MB of hash.k2d")
    print(f"Found {len(sequence_markers)} potential taxonomy markers")
    print("\nMost common 8-byte patterns:")
    for pattern, count in sorted(patterns.items(), key=lambda x: x[1], reverse=True)[:5]:
        print(f"Pattern: {pattern.hex()} Count: {count}")

def main():
    print("Analyzing opts.k2d...")
    read_opts_k2d("opts.k2d")
    
    print("\nAnalyzing taxo.k2d...")
    tax_ids, parent_child = read_taxo_k2d("taxo.k2d")
    
    print("\nPeeking into hash.k2d...")
    peek_hash_k2d("hash.k2d")

if __name__ == "__main__":
    main()