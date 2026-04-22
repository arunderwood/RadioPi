#!/usr/bin/env bash
# start.sh — Launch Dire Wolf for portable packet radio on macOS.
#
# Detects the AIOC, patches the config with the correct device paths,
# and runs Dire Wolf in the foreground.  Tune your HT to 145.050 MHz
# before starting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_SRC="${SCRIPT_DIR}/direwolf.conf"
CONF_TMP="/tmp/direwolf-portable.conf"

cleanup() {
    rm -f "$CONF_TMP"
}
trap cleanup EXIT INT TERM

# --- Prerequisites ---

if ! command -v direwolf >/dev/null 2>&1; then
    echo "ERROR: direwolf not found.  Install it with:" >&2
    echo "       brew install direwolf" >&2
    exit 1
fi

# --- Detect AIOC ---

# shellcheck source=find-aioc.sh
source "${SCRIPT_DIR}/find-aioc.sh"

# --- Build runtime config ---

sed \
    -e "s|__AIOC_AUDIO__|${AIOC_AUDIO}|g" \
    -e "s|__AIOC_SERIAL__|${AIOC_SERIAL}|g" \
    -e "s|__AIOC_IN__|${AIOC_IN}|g" \
    -e "s|__AIOC_OUT__|${AIOC_OUT}|g" \
    "$CONF_SRC" > "$CONF_TMP"

# --- Summary ---

echo ""
echo "=== Portable Packet Radio ==="
echo "  Callsign:     W9CPZ"
echo "  Frequency:    145.050 MHz (set on HT)"
echo "  PTT device:   ${AIOC_SERIAL}"
echo "  Audio device: ${AIOC_AUDIO}"
echo "  KISS TCP:     localhost:8001"
echo "  AGW TCP:      localhost:8000"
echo ""
echo "Connect a packet terminal to localhost:8001 (KISS TCP)."
echo "Press Ctrl-C to stop."
echo ""

# --- Launch ---

if [ "${1:-}" = "--cal" ]; then
    echo "Calibration mode: sending alternating mark/space tones."
    echo "Listen on another radio.  Ctrl-C to stop."
    direwolf -x a -c "$CONF_TMP"
else
    direwolf -c "$CONF_TMP" -t 0
fi
