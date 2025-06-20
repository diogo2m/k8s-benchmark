#!/bin/bash

# Check arguments
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 SERVER_IP SERVER_PORT NUM_CLIENTS NUM_REQUESTS"
  exit 1
fi

SERVER_IP="$1"
SERVER_PORT="$2"
NUM_CLIENTS="$3"
NUM_REQUESTS="$4"

# Timestamped output directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="client_results_$TIMESTAMP"
OUTPUT_DIR=/mnt/k8s-results
mkdir -p "$OUTPUT_DIR"

# Function to simulate a client
simulate_client() {
  local client_id="$1"
  local output_file="$OUTPUT_DIR/client_${client_id}.csv"

  echo "Request#,RTT_seconds" > "$output_file"

  for ((req=1; req<=NUM_REQUESTS; req++)); do
    start_time=$(date +%s.%N)
    
    # Send a simple message to the server and receive response
    # Using /dev/tcp for quick TCP test
    echo "Hello from client $client_id, request $req" | nc "$SERVER_IP" "$SERVER_PORT" > /dev/null 2>&1

    end_time=$(date +%s.%N)
    rtt=$(echo "$end_time - $start_time" | bc)

    echo "$req,$rtt" >> "$output_file"
  done
}

# Start all clients in the background
for ((i=1; i<=NUM_CLIENTS; i++)); do
  simulate_client "$i" &
done

# Wait for all clients to complete
wait

echo "All clients completed. Output stored in $OUTPUT_DIR"
