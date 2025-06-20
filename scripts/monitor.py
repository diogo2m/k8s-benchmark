import time
import re
import subprocess
from collections import Counter, defaultdict

# Mock function to replace with actual data input (e.g., from kubectl or a file)
def get_current_table():
    return subprocess.getoutput("kubectl top pods --no-headers")

def parse_resource_usage(data: str):
    lines = data.strip().splitlines()
    if not lines or len(lines) < 2:
        return []

    headers = lines[0].split()
    parsed = []
    for line in lines[1:]:
        parts = line.split()
        name = " ".join(parts[:-2])
        cpu = parts[-2]
        mem = parts[-1]
        parsed.append({
            'name': name,
            'cpu': cpu,
            'memory': mem
        })
    return parsed

def parse_cpu(cpu_str):
    return int(cpu_str.rstrip('m')) if cpu_str.endswith('m') else int(cpu_str) * 1000

def parse_memory(mem_str):
    if mem_str.endswith("Mi"):
        return int(mem_str.rstrip("Mi"))
    elif mem_str.endswith("Gi"):
        return int(mem_str.rstrip("Gi")) * 1024
    return int(mem_str)

def daemon_loop(timeout=60, interval=2):
    server_counter = Counter()
    cpu_total = 0
    mem_total = 0
    client_count = 0
    server_count = 0

    last_seen = time.time()

    print("Daemon started. Monitoring...")

    while True:
        table = get_current_table()
        entries = parse_resource_usage(table)
        clients = [e for e in entries if e['name'].startswith('client-job-')]
        servers = [e for e in entries if e['name'].startswith('server-deploy-')]

        if clients:
            last_seen = time.time()
            for s in servers:
                server_counter[s['name']] += 1
                cpu_total += parse_cpu(s['cpu'])
                mem_total += parse_memory(s['memory'])
                server_count += 1
            client_count += len(clients)
        else:
            if time.time() - last_seen > timeout:
                print("No clients detected for too long. Exiting.")
                break

        time.sleep(interval)

    if client_count == 0 or server_count == 0:
        print("No client-job entries were detected.")

    # Results
    #most_common = server_counter.most_common(1)[0]
    avg_cpu_millicores = cpu_total / server_count
    avg_mem_mib = mem_total / server_count

    print("\nSummary:")
    #print(f"Most frequent server: {most_common[0]} (seen {most_common[1]} times)")
    print(f"Average CPU: {avg_cpu_millicores:.2f} millicores")
    print(f"Average Memory: {avg_mem_mib:.2f} MiB")

# Run the daemon
if __name__ == "__main__":
    daemon_loop(timeout=60, interval=2)
