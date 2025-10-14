#!/bin/bash

# Usage check
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 SERVER_IP SERVER_PORT NUM_CLIENTS NUM_REQUESTS"
    exit 1
fi

SERVER_IP="$1"
SERVER_PORT="$2"
NUM_CLIENTS="$3"
NUM_REQUESTS="$4"

# Output directory
OUTPUT_DIR="/mnt/k8s-results"
mkdir -p "$OUTPUT_DIR"

# Limit maximum simultaneous clients to avoid overloading
MAX_PARALLEL=256  # tune this to your system

# Function to simulate a client
simulate_client() {
    local client_id="$1"
    local output_file="$OUTPUT_DIR/client_${client_id}.csv"
    echo "Request#,RTT_seconds" > "$output_file"

    for ((req=1; req<=NUM_REQUESTS; req++)); do
        start_time=$(date +%s.%N)

        # Use nc with 1s timeout, suppress output
        if ! echo "Hello from client $client_id, request $req" | nc -w 1 "$SERVER_IP" "$SERVER_PORT" > /dev/null 2>&1; then
            rtt="FAIL"
        else
            end_time=$(date +%s.%N)
            rtt=$(awk "BEGIN {print $end_time-$start_time}")
        fi

        echo "$req,$rtt" >> "$output_file"
    done
}

# Export function for parallel execution
export -f simulate_client
export SERVER_IP SERVER_PORT NUM_REQUESTS OUTPUT_DIR

# Run clients in parallel using GNU Parallel
seq 1 $NUM_CLIENTS | parallel -j $MAX_PARALLEL simulate_client {}

echo "All clients completed. Output stored in $OUTPUT_DIR"
