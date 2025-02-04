#!/usr/bin/env bash

# Usage:
#   ./run_benchmark.sh "<TOOL_NAME>"
# Example:
#   ./run_benchmark.sh "Kraken2"

# Exit immediately if a pipeline returns non-zero status
set -o errexit
set -o pipefail
# Treat unset variables as an error
set -o nounset

# --------------------------- CONFIGURATIONS --------------------------- #

# Path to the benchmark_tool.sh script
BENCHMARK_SCRIPT="./benchmark_tool.sh"

# Input and output directories
INPUT_DIR="input_fq"
OUTPUT_BASE_DIR="output"

# Supported tools and their command templates
declare -A TOOL_COMMANDS

# Define command templates with placeholders {input_fq} and {output_path}
TOOL_COMMANDS["FALCON"]="FALCON -v -F -t 15 -l 47 -n 4 -x {output_path} {input_fq} falcon/viruses_DB.fa"
TOOL_COMMANDS["KRAKEN"]="kraken2 -db viruses_kraken_db/ --threads 4 {input_fq} > {output_path}"
TOOL_COMMANDS["CLARK"]="./CLARKV1.3.0.0/classify_metagenome.sh -O {input_fq} -R {output_path} --light -n 4"
TOOL_COMMANDS["KAIJU"]="kaiju -t kaiju/nodes.dmp -f kaiju/viruses.fmi -i {input_fq} -z 4 -o {output_path}"
TOOL_COMMANDS["CENTRIFUGE"]="centrifuge -p 4 -x centrifuge/viruses_db -q {input_fq} > {output_path}"

# --------------------------- FUNCTIONS --------------------------- #

# Function to display usage information
usage() {
    echo "Usage: $0 \"<TOOL_NAME>\""
    echo "Supported TOOL_NAME values: FALCON, KRAKEN, CLARK, KAIJU, CENTRIFUGE"
    echo "Example:"
    echo "  $0 \"KRAKEN\""
    exit 1
}

# Function to check if benchmark_tool.sh exists and is executable
check_benchmark_script() {
    if [[ ! -f "$BENCHMARK_SCRIPT" ]]; then
        echo "Error: Benchmark script '$BENCHMARK_SCRIPT' not found."
        exit 1
    fi

    if [[ ! -x "$BENCHMARK_SCRIPT" ]]; then
        echo "Error: Benchmark script '$BENCHMARK_SCRIPT' is not executable."
        exit 1
    fi
}

# --------------------------- MAIN --------------------------- #

# Check for exactly one argument
if [[ $# -ne 1 ]]; then
    usage
fi

TOOL_NAME="$1"

# Check if the tool is supported
if [[ -z "${TOOL_COMMANDS[$TOOL_NAME]+_}" ]]; then
    echo "Error: Unsupported tool name '$TOOL_NAME'."
    echo "Supported TOOL_NAME values: FALCON, KRAKEN, CLARK, KAIJU, CENTRIFUGE"
    exit 1
fi

# Check benchmark_tool.sh
check_benchmark_script

# Define the path to the output directory
OUTPUT_DIR="${OUTPUT_BASE_DIR}/${TOOL_NAME}"

# Create the tool-specific output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Iterate over each .fq and .fastq file in the input directory
shopt -s nullglob
FILES=("$INPUT_DIR"/*.fq "$INPUT_DIR"/*.fastq)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No .fq or .fastq files found in '$INPUT_DIR'."
    exit 1
fi

# Loop through each file and run benchmarking
for INPUT_FILE in "${FILES[@]}"; do
    # Extract the base filename without path and extension
    BASE_NAME="$(basename $INPUT_FILE)"
    BASE_NAME="${BASE_NAME%.*}"

    # Define the output path, including the tool name and base filename
    # For tools that redirect output to files, define output file extensions accordingly
    case "$TOOL_NAME" in
        FALCON)
            OUTPUT_PATH="${OUTPUT_DIR}/${BASE_NAME}_falcon.txt"
            ;;
        Kraken2)
            OUTPUT_PATH="${OUTPUT_DIR}/${BASE_NAME}_kraken2.txt"
            ;;
        CLARK)
            OUTPUT_PATH="${OUTPUT_DIR}/${BASE_NAME}_clark.txt"
            ;;
        Kaiju)
            OUTPUT_PATH="${OUTPUT_DIR}/${BASE_NAME}_kaiju.txt"
            ;;
        Centrifuge)
            OUTPUT_PATH="${OUTPUT_DIR}/${BASE_NAME}_centrifuge.txt"
            ;;
        *)
            echo "Error: Output path for '$TOOL_NAME' not defined."
            exit 1
            ;;
    esac

    # Replace the placeholders {input_fq} and {output_path} in the command template
    COMMAND_TEMPLATE="${TOOL_COMMANDS[$TOOL_NAME]}"
    
    # Properly escape the input and output paths with quotes to handle spaces or special characters
    COMMAND="${COMMAND_TEMPLATE//\{input_fq\}/$INPUT_FILE}"
    COMMAND="${COMMAND//\{output_path\}/$OUTPUT_PATH}"

    COMPLETE_COMMAND="$TOOL_NAME \"$COMMAND\""

    echo "Benchmarking $TOOL_NAME on $BASE_NAME..."
    echo "Executing command: $COMPLETE_COMMAND"

    # Execute the benchmark_tool.sh script with the tool name and command
    # The command is passed as a single string to handle redirections and other shell-specific syntax
    bash "$BENCHMARK_SCRIPT" "$TOOL_NAME" "$COMMAND"

    echo "Completed: $BASE_NAME"
done

# Removed the final echo that referenced LOGFILE
echo "All benchmarks completed. Check the respective '$OUTPUT_DIR' directories for results."
