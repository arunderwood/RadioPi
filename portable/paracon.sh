#!/usr/bin/env bash
# paracon.sh — Download (if needed) and launch Paracon packet terminal.
#
# Paracon connects to Dire Wolf's AGW port (8000).  Start Dire Wolf
# first with ./start.sh, then run this in a second terminal.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARACON_DIR="${SCRIPT_DIR}/.paracon"
PARACON_PYZ="${PARACON_DIR}/paracon.pyz"
RELEASE_URL="https://api.github.com/repos/mfncooper/paracon/releases/latest"

mkdir -p "$PARACON_DIR"

# --- Download or update ---

if [ ! -f "$PARACON_PYZ" ]; then
    echo "Downloading Paracon..."
    download_url=$(curl -sL "$RELEASE_URL" \
        | python3 -c "import sys,json; r=json.load(sys.stdin); print([a['browser_download_url'] for a in r['assets'] if a['name'].endswith('.pyz')][0])")
    curl -sL -o "$PARACON_PYZ" "$download_url"
    chmod +x "$PARACON_PYZ"
    echo "Downloaded $(basename "$(curl -sL "$RELEASE_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")")"
fi

# --- Launch ---

echo "Starting Paracon (connects to Dire Wolf AGW on localhost:8000)..."
echo "Type /help in Paracon for commands."
echo ""
python3 "$PARACON_PYZ"
