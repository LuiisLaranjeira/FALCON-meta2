import re
import os

def extract_accession(ref_string):
    """
    Extract the accession using a regex that looks for
    'NC_' followed by digits, a dot, then more digits.
    """
    match = re.match(r'^(NC_\d+\.\d+)', ref_string)
    if match:
        return match.group(1)
    else:
        return ref_string 

def get_depth_from_filename(filename):
    """
    Extracts the depth from a filename of the form:
    sim_depth1_read20_deam0.3_s_falcon.txt
    
    In the above example, this returns 1 (as an integer).
    If no 'depth' pattern is found, returns None.
    """
    match = re.search(r'depth(\d+)', filename)
    if match:
        return int(match.group(1))
    else:
        return None
    
def choose_thresholds(depth):
    """
    Return threshold depending on depth.
    Here we define a simple, example-based policy:
      - If depth < 5, threshold = 80%
      - If 5 <= depth < 20, threshold = 90%
      - If depth >= 20, threshold = 95%
    """
    if depth is None:
        # default or fallback
        return 70.0
    
    if depth < 5:
        return 10.0
    elif depth < 20:
        return 30.0
    else:
        return  90.0

def evaluate_file(filepath, ground_truth, output_handle):
    """
    Given a single file (table structure), parse it and compute
    TP, FP, FN, TN, Precision, Recall, F1.
    
    Writes the results as a single line to the open output file handle.
    """
    filename = os.path.basename(filepath)
    depth = get_depth_from_filename(filename)
    
    # Choose thresholds based on depth
    threshold = choose_thresholds(depth)
    
    # Initialize confusion matrix counters
    TP = 0
    FP = 0
    TN = 0
    FN = 0
    
    detected_refs = set()
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) < 4:
                continue  # skip malformed or header lines

            # rank = parts[0]  # if you want to store
            # coverage_or_len = float(parts[1])  # if you want to parse coverage
            identity = float(parts[2])
            ref_str = parts[3]
            
            ref_id = extract_accession(ref_str)
            predicted_positive = (identity >= threshold)
            truly_present = (ref_id in ground_truth)
            
            if predicted_positive and truly_present:
                TP += 1
                detected_refs.add(ref_id)
            elif predicted_positive and not truly_present:
                FP += 1
            elif not predicted_positive and truly_present:
                # We'll account for missed references after
                pass
            else:
                # not predicted, not in ground truth -> true negative
                TN += 1
    
    # Any ground-truth reference never detected => FN
    for gt_id in ground_truth:
        if gt_id not in detected_refs:
            FN += 1
    
    # Compute metrics
    precision = TP / (TP + FP) if (TP + FP) else 0.0
    recall    = TP / (TP + FN) if (TP + FN) else 0.0
    f1        = 2 * (precision * recall) / (precision + recall) if (precision + recall) else 0.0
    
    # Write results to the output file (tab-delimited)
    # Format: filename, depth, TP, FP, FN, TN, precision, recall, f1
    line = f"{filename},{depth},{TP},{FP},{FN},{TN},{precision:.3f},{recall:.3f},{f1:.3f}\n"
    output_handle.write(line)


def main():
    directory = "output/FALCON"  # your directory with the input files
    output_filename = "results_summary.csv"
    
    # Ground truth references
    ground_truth = {
        "NC_013511.1",
        "NC_000883.2",
        "NC_001806.2",
        "NC_009823.1",
        "NC_022518.1",
        "NC_001558.1"
    }

    # Ground truth references with bacteria
    # ground_truth = {
    #     "NC_013511.1",
    #     "NC_000883.2",
    #     "NC_001806.2",
    #     "NC_009823.1",
    #     "NC_022518.1",
    #     "NC_001558.1",
    #     "NZ_CP069645.1"
    # }

# Check if the CSV file already exists to see if we need a header.
    file_exists = os.path.isfile(output_filename)
    
    # Open the output file in append mode
    with open(output_filename, "a") as out:
        # If the file is new, write a header row
        if not file_exists:
            out.write("Filename,Depth,TP,FP,FN,TN,Precision,Recall,F1\n")
        
        # Iterate over each file in the directory
        for filename in os.listdir(directory):
            if not filename.endswith(".txt"):
                continue
            
            filepath = os.path.join(directory, filename)
            evaluate_file(filepath, ground_truth, output_handle=out)

if __name__ == "__main__":
    main()