# Portable Packet Radio — macOS + AIOC + HT

Standalone macOS setup for connecting to the local 145.050 MHz packet
network using a handheld transceiver and the
[AIOC (All-In-One Cable)](https://skuep.github.io/AIOC/) USB device.

This is a lightweight field setup — not a full node or BBS.  For the
permanent station, see the Ansible-managed `aloha` host in `ansible/`.

## Hardware

- MacBook (Apple Silicon or Intel)
- Handheld transceiver tuned to 145.050 MHz
- AIOC (All-In-One Cable) — USB audio + serial + PTT in one device
  - **Firmware v1.4.0+ required** for macOS TX audio to work. Earlier
    versions can RX and key PTT but transmit silence. See
    [Updating AIOC firmware](#updating-aioc-firmware) below.
- USB-C cable that supports data (not power-only)

## Prerequisites

```
brew install direwolf
```

Verify: `direwolf -v` should print version 1.7+.

## Quick Start

```
cd portable
./start.sh
```

The script finds the AIOC, configures Dire Wolf, and starts it.
Tune the HT to **145.050 MHz** before starting.

## Connecting a Packet Terminal

Dire Wolf exposes a KISS TCP port on `localhost:8001`.  Connect any
KISS-capable terminal to use AX.25 and NET/ROM.

### Paracon (recommended)

[Paracon](https://github.com/mfncooper/paracon) is a mature,
zero-dependency packet terminal that runs in the terminal.  It connects
to Dire Wolf's AGW port (8000).  A launcher script downloads it
automatically:

```
./paracon.sh
```

First run downloads the `.pyz` file from GitHub.  Subsequent runs
launch immediately.  Requires only Python 3.9+ (already on macOS).

See the [Paracon docs](https://paracon.readthedocs.io) for usage —
type `/help` inside Paracon for commands.

### Other Clients

Any application that speaks AGW (port 8000) or KISS TCP (port 8001)
can connect to Dire Wolf.  Examples: QtTermTCP, Xastir, YAAC.

## AIOC Device Discovery

If `start.sh` cannot find the AIOC, run the discovery helper directly:

```
./find-aioc.sh
```

This prints the detected serial port and audio device name.

To manually list Dire Wolf audio devices:

```
direwolf -l
```

To check for the AIOC serial port:

```
ls /dev/cu.usbmodem*
```

## Audio Levels

macOS does not have `amixer`.  Audio levels are controlled via:

1. **macOS System Settings** > Sound > Input/Output — select the AIOC
   device and adjust the level slider.
2. **Dire Wolf waterfall** — Dire Wolf logs the received audio level.
   Target the same 25-50 range as the Linux setup (see
   `docs/audio-level-tuning.md`).

Start with the macOS input level at ~50% and adjust based on Dire Wolf's
audio level display.

## Differences from the Linux (aloha) Setup

| Feature | aloha (Linux) | Portable (macOS) |
|---------|--------------|------------------|
| TNC | Dire Wolf (systemd) | Dire Wolf (foreground) |
| Packet stack | LinBPQ (full node/BBS) | Paracon (terminal client) |
| AX.25 | LinBPQ built-in | Userspace (Paracon via AGW) |
| NET/ROM | LinBPQ built-in | Not available |
| PTT | Serial RTS (DigiRig) | Serial RTS (AIOC) |
| Audio control | ALSA amixer | macOS System Settings |
| Audio interface | DigiRig Mobile | AIOC |
| Managed by | Ansible | Manual (scripts in this dir) |

## Updating AIOC firmware

The AIOC ships with firmware that may predate the macOS USB Audio Class
output fixes (added in v1.4.0).  Symptom: PTT keys the radio but no
audio is transmitted (carrier only, no modulation).  RX works fine.

Update via DFU:

```
brew install dfu-util
curl -LO https://github.com/skuep/AIOC/releases/latest/download/aioc-fw-1.4.1.bin
dfu-util -d 1209:7388 -a 0 -s 0x08000000:leave -D aioc-fw-1.4.1.bin
```

The AIOC reboots itself into bootloader mode, flashes, and reboots
back.  Don't unplug it during the process.  After it comes back, unplug
and replug the USB cable so macOS reinitializes the audio descriptors.

To verify or check the current firmware, use the [aioc-util tool](https://github.com/hrafnkelle/aioc-util):

```
git clone https://github.com/hrafnkelle/aioc-util.git
cd aioc-util && python3 -m venv venv && source venv/bin/activate
pip install hid
./aioc-util.py --dump
```

## macOS Limitations

- **No kernel AX.25** — macOS has no AX.25/NET/ROM kernel modules.
  All packet networking runs in userspace via KISS TCP.
- **No CM108 GPIO PTT** — the AIOC's CM108 GPIO mode is Linux-only.
  The serial DTR/RTS mode works on macOS and is used instead.  The
  AIOC keys PTT when DTR=1 AND RTS=0, so the Dire Wolf config uses
  `PTT <port> DTR -RTS` (asserting RTS would un-key the radio).
- **No ALSA** — audio levels are set via System Settings, not `amixer`.
