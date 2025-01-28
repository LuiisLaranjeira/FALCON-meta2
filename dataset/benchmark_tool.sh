#!/usr/bin/env bash

# Usage:
#   ./benchmark_tool.sh "<TOOL_NAME>" <COMMAND...>
# Example:
#   ./benchmark_tool.sh "Kraken2" kraken2 --db MINIKRAKEN_DB input.fq
#
# This script will:
#   1. Record the date/time, tool name, command, real time, user time, sys time, max RAM (in KB), and exit code.
#   2. Append the data to 'benchmark_log.csv' in the current directory.

# Exit immediately if a pipeline returns non-zero status
set -o errexit
set -o pipefail
# Treat unset variables as an error
set -o nounset

# --------------------------- CONFIGURATIONS --------------------------- #
LOGFILE="benchmark_log.csv"
TIMEFILE="$(mktemp)"

# --------------------------- ARGUMENTS --------------------------- #
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <TOOL_NAME> <COMMAND...>"
  exit 1
fi

TOOL_NAME="$1"
shift
COMMAND_TO_RUN="$*"

# --------------------------- MAIN --------------------------- #

# If the log file doesn't exist, write a header (optional).
if [[ ! -f "$LOGFILE" ]]; then
  echo "timestamp,tool_name,command,real_time_sec,user_time_sec,sys_time_sec,max_ram_kb,exit_code" > "$LOGFILE"
fi

# Check if /usr/bin/time exists and is GNU time
if ! /usr/bin/time --version >/dev/null 2>&1; then
  echo "/usr/bin/time not found or not GNU time. Please install GNU time."
  exit 1
fi

# Run the command with /usr/bin/time in 'custom' format.
#   %e = elapsed real time (in seconds)
#   %U = user CPU time
#   %S = system CPU time
#   %M = maximum resident set size (in KB)
#   %x = exit status of the command
/usr/bin/time --output="$TIMEFILE" --format="%e %U %S %M %x" $COMMAND_TO_RUN || true

# Read results from time output
read -r REAL_TIME USER_TIME SYS_TIME MAX_RAM EXIT_CODE < "$TIMEFILE"

# Capture the date/time
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"

# Escape double quotes in the command to avoid CSV issues
ESCAPED_COMMAND=$(echo "$COMMAND_TO_RUN" | sed 's/"/""/g')

# Append results to log (in CSV format)
echo "\"${TIMESTAMP}\",\"${TOOL_NAME}\",\"${ESCAPED_COMMAND}\",${REAL_TIME},${USER_TIME},${SYS_TIME},${MAX_RAM},${EXIT_CODE}" >> "$LOGFILE"

# Cleanup
rm -f "$TIMEFILE"

# Use the exit code from the command
exit "${EXIT_CODE}"
