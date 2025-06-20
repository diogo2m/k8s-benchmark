import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import rcParams
import matplotlib.font_manager as fm
import os

if len(sys.argv) > 1:
    filename = sys.argv[1]
else:
    raise ValueError("Please provide a CSV filename as a command-line argument.")

# Load data from file
df = pd.read_csv(filename)

# Extract client, server, and message counts from label
df[['clients', 'servers', 'messages']] = df['label'].str.extract(r'(\d+)clients-(\d+)servers-(\d+)messages').astype(int)

# Optional: Load and use Roboto font if installed
try:
    roboto_path = fm.findfont("Roboto")
    rcParams['font.family'] = fm.FontProperties(fname=roboto_path).get_name()
except:
    print("Roboto font not found. Falling back to default font.")

# Unique message counts
unique_messages = sorted(df['messages'].unique())

# Line styles and colors
linestyles = ['--', '-.', ':', '-', (0, (3, 1, 1, 1))]

# Create output directory for plots
output_dir = "plots"
os.makedirs(output_dir, exist_ok=True)

for msg in unique_messages:
    df_msg = df[df['messages'] == msg]
    pivot = df_msg.pivot(index='clients', columns='servers', values='RTT_seconds')

    plt.figure(figsize=(14, 8))
    colors = plt.cm.viridis_r(np.linspace(0, 1, len(pivot.columns)))

    for i, server in enumerate(sorted(pivot.columns)):
        plt.plot(
            pivot.index,
            pivot[server],
            linestyle=linestyles[i % len(linestyles)],
            marker='o',
            color=colors[i],
            label=f'{server} servers'
        )

    plt.title(f'RTT vs Clients (Messages = {msg})', fontsize=20)
    plt.xlabel('Number of Clients', fontsize=16)
    plt.ylabel('RTT (seconds)', fontsize=16)
    plt.grid(True, which='both', linestyle=':', linewidth=0.5)
    plt.legend(title="Servers", fontsize=12)
    plt.xticks(fontsize=12)
    plt.yticks(fontsize=12)
    plt.tight_layout()

    filename_base = f"rtt_vs_clients_{msg}messages"
    plt.savefig(os.path.join(output_dir, f"{filename_base}.png"), dpi=300)
    plt.close()

print(f"Plots saved in folder: {output_dir}")

