#!/bin/bash
set -e

CURRENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root"
  exit 1
fi

apt update && apt upgrade -y
apt install -y python3-pip

pip install -r requirements.txt

mkdir -p /mnt/k8s-results

bash scripts/build.sh
