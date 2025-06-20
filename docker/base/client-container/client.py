import socket
import time
import sys
import csv
import os

def parse_args(argv):
    parsed = {}
    last_flag = None

    for arg in argv[1:]:  # Skip the script name
        if arg.startswith("-"):
            last_flag = arg.lstrip("-")
            parsed[last_flag] = None  # Default to None if no value follows
        else:
            if last_flag is None:
                raise ValueError(f"Value '{arg}' has no associated flag.")
            if parsed[last_flag] is None:
                parsed[last_flag] = arg
            else:
                # Support multiple values per flag
                if isinstance(parsed[last_flag], list):
                    parsed[last_flag].append(arg)
                else:
                    parsed[last_flag] = [parsed[last_flag], arg]
    
    return parsed

args = parse_args(sys.argv)

SERVER_HOST = "10.99.11.100"   # Change this to your LoadBalancer or NodePort IP
SERVER_PORT = 80               # Match this with your exposed Kubernetes service port
NUM_REQUESTS = args.get("n", 50)              # Total number of requests to send
CSV_FILENAME = f"/results/results_{os.environ['HOSTNAME']}.csv"

# Create the directory if it doesn't exist
os.makedirs("/results", exist_ok=True)

def measure_request_time(host, port):
    try:
        start_time = time.time()

        client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client_socket.settimeout(5)
        client_socket.connect((host, port))

        # Send a basic HTTP GET request
        request = "GET / HTTP/1.1\r\nHost: {}\r\n\r\n".format(host)
        client_socket.send(request.encode())

        response = client_socket.recv(4096)
        end_time = time.time()

        client_socket.close()
        return end_time - start_time, response.decode()
    except Exception as e:
        return None, f"Error: {e}"

def main():
    with open(CSV_FILENAME, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(["Request#", "RTT_seconds"])

        for i in range(1, NUM_REQUESTS + 1):
            rtt, response = measure_request_time(SERVER_HOST, SERVER_PORT)
            if rtt is not None:
                print(f"Request {i}: RTT = {rtt:.4f}s")
                writer.writerow([i, rtt])
            else:
                print(f"Request {i}: Failed - {response}")
                writer.writerow([i, "FAILED"])

if __name__ == "__main__":
    main()

