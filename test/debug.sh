#!/bin/bash

# This script is used to run the FALCON assembler with valgrind for debugging purposes.
# It runs the FALCON assembler with specific parameters and checks for memory leaks.
# Usage: ./debug.sh
# Ensure that the script is executable
# by running: chmod +x debug.sh

set -e

# Configuration
FALCON="./FALCON"
BASE_PARAMS="meta -v -F -t 15 -l 47 -x top.txt"
INPUT_FILES="reads.fq"
VALGRIND="valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes"

# Check dependencies
if ! command -v valgrind &> /dev/null; then
    echo "Error: valgrind not found"
    exit 1
fi

if [ ! -x "$FALCON" ]; then
    echo "Error: FALCON not found"
    exit 1
fi

# Run tests
run_test() {
    echo "Running FALCON $1..."
    $VALGRIND $FALCON $BASE_PARAMS $2 $INPUT_FILES
    echo ""
}

# Simple test
#run_test "simple test" ""

# Model tests
#run_test "save model test" "--save-model"
#run_test "load model test" "--load-model"
#run_test "load model with info" "--load-model --model-info"
run_test "train model" "--train-model"

echo "All tests completed"