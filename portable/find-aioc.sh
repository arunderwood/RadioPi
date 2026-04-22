#!/usr/bin/env bash
# find-aioc.sh — Detect the AIOC (All-In-One Cable) USB device on macOS.
# Exports AIOC_SERIAL and AIOC_AUDIO for use by start.sh.
# Can also be run standalone for diagnostics.
set -euo pipefail

# --- Serial port detection ---

# Look for the AIOC's USB serial port.  The AIOC enumerates a CDC-ACM
# serial device that macOS exposes as /dev/cu.usbmodem*.
aioc_serial=""
for dev in /dev/cu.usbmodem*; do
    [ -e "$dev" ] || continue
    aioc_serial="$dev"
    break
done

if [ -z "$aioc_serial" ]; then
    echo "ERROR: No /dev/cu.usbmodem* device found." >&2
    echo "       Is the AIOC plugged in?  Try a different USB-C cable" >&2
    echo "       (must support data, not power-only)." >&2
    exit 1
fi

# Confirm the USB device is actually an AIOC.  ioreg lists USB devices
# with the product name; the AIOC shows up as "All-In-One-Cable" or
# "All_In_One_Cable" depending on context.
if ioreg -p IOUSB -w0 2>/dev/null | grep -qi "All.In.One.Cable"; then
    echo "AIOC USB device confirmed"
else
    echo "WARNING: Found ${aioc_serial} but could not confirm it is an AIOC." >&2
    echo "         Proceeding anyway — if PTT fails, check the cable." >&2
fi

export AIOC_SERIAL="$aioc_serial"
echo "Serial port: ${AIOC_SERIAL}"

# --- Audio device detection ---

# Dire Wolf on macOS uses CoreAudio device names.  Run `direwolf -l` to
# list available devices and look for one that looks like the AIOC.
# Common names: "AIOC", "All-In-One-Cable", or the CM108 chip name.
# The AIOC registers as "AIOC Audio" in CoreAudio.  It presents as
# TWO PortAudio devices with the same name — one input-only (RX from
# radio) and one output-only (TX to radio).  Dire Wolf needs both
# specified by device index to route audio correctly.
#
# Dire Wolf has no flag to list audio devices without starting up, so
# we hardcode the name and detect device indices from a throwaway
# direwolf startup.
aioc_audio="AIOC Audio"

# Detect PortAudio device indices.  Dire Wolf prints a numbered list
# at startup.  We grab it by running direwolf briefly and parsing
# the output.  The input device has "Max inputs  = 1" and the output
# device has "Max outputs = 1".
aioc_in=""
aioc_out=""
if command -v direwolf >/dev/null 2>&1; then
    # Run direwolf with a bad config to make it print devices and exit.
    dw_devs=$(direwolf -c /dev/null 2>&1 || true)
    # Parse device blocks: "device #N" followed by Name and Max lines.
    current_dev=""
    while IFS= read -r line; do
        case "$line" in
            *"device #"*)
                current_dev=$(echo "$line" | sed 's/.*device #\([0-9]*\).*/\1/')
                ;;
            *"AIOC"*"Max inputs"*"= 1"*)
                aioc_in="$current_dev"
                ;;
            *"AIOC"*"Max outputs"*"= 1"*)
                aioc_out="$current_dev"
                ;;
            *"Max inputs"*"= 1"*)
                if echo "$prev_name" | grep -qi "AIOC"; then
                    aioc_in="$current_dev"
                fi
                ;;
            *"Max outputs"*"= 1"*)
                if echo "$prev_name" | grep -qi "AIOC"; then
                    aioc_out="$current_dev"
                fi
                ;;
        esac
        if echo "$line" | grep -q "^Name"; then
            prev_name="$line"
        fi
    done <<< "$dw_devs"
fi

# Fall back to typical indices if detection failed.
if [ -z "$aioc_in" ]; then aioc_in=1; fi
if [ -z "$aioc_out" ]; then aioc_out=0; fi

export AIOC_AUDIO="$aioc_audio"
export AIOC_IN="$aioc_in"
export AIOC_OUT="$aioc_out"
echo "Audio device: ${AIOC_AUDIO} (in=#${AIOC_IN}, out=#${AIOC_OUT})"
