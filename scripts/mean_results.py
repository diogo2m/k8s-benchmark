import pandas as pd
import glob
import os
import sys

# === Config ===
input_folder = '/mnt/k8s-results'
output_file = 'average_result.csv'

# === Get label from CLI ===
if len(sys.argv) < 2:
    print("Usage: python mean_results.py <label>")
    sys.exit(1)

label = sys.argv[1]

# === Find all CSV files ===
csv_files = glob.glob(os.path.join(input_folder, '*.csv'))
if not csv_files:
    print("No CSV files found.")
    sys.exit(1)

# === Load and validate CSVs ===
valid_dfs = []
for file in csv_files:
    if os.path.getsize(file) == 0:
        print(f"⚠️ Skipping empty file: {file}")
        continue
    try:
        df = pd.read_csv(file)
        if df.empty or df.columns.size == 0:
            print(f"⚠️ Skipping file with no data or columns: {file}")
            continue
        valid_dfs.append(df)
    except pd.errors.EmptyDataError:
        print(f"⚠️ Skipping unreadable file: {file}")
        continue

if not valid_dfs:
    print("❌ No valid data found in any CSV.")
    sys.exit(1)

# === Combine all valid data ===
combined_df = pd.concat(valid_dfs, ignore_index=True)

# === Drop first column (assumed to be index like "Request#") ===
combined_df = combined_df.iloc[:, 1:]

# === Keep only numeric columns ===
numeric_df = combined_df.select_dtypes(include='number')

if numeric_df.empty:
    print("❌ No numeric data available after filtering.")
    sys.exit(1)

# === Compute mean ===
averages = numeric_df.mean().to_dict()
row = {'label': label}
row.update(averages)
result_df = pd.DataFrame([row])

# === Append or create output file ===
if os.path.exists(output_file):
    existing_df = pd.read_csv(output_file)
    result_df = pd.concat([existing_df, result_df], ignore_index=True)

# === Save result ===
result_df.to_csv(output_file, index=False)
print(f"✅ Saved average for '{label}' to {output_file}")

