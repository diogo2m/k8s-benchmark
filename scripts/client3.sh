#!/bin/bash



taskset -c 8 bash -c '
  (
    while true; do
      for i in {1..2048}; do
        printf "Request 1\r\n"
      done
      sleep 0.0001 # Wait between requests
    done
  ) | nc localhost 80
'
