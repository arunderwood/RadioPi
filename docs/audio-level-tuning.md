# Audio Level Tuning — Direwolf + DigiRig Mobile

Procedure for setting correct audio levels between Direwolf on aloha and the radio via the DigiRig Mobile USB interface.

The radio's audio levels should not need adjustment — only the Pi-side ALSA mixer controls are tuned here.

## Prerequisites

- SSH access to aloha
- DigiRig Mobile connected via USB (audio + serial)
- Radio connected to DigiRig, powered on, tuned to the target frequency
- Another radio or SDR available to monitor your TX signal

## 1. Verify the DigiRig is recognized

```bash
# Confirm USB audio device is present
arecord -l | grep Device
# Expected: card N: Device [USB Audio Device], device 0: USB Audio [USB Audio]

# Confirm ALSA mixer controls exist
amixer -c Device scontrols
# Expected: shows Capture and/or Speaker/Playback controls
```

If "Device" isn't found, check `lsusb` for the CP2102 and USB audio entries. The DigiRig presents two USB devices: a serial port (CP2102) and a sound card.

## 2. Stop Direwolf

Direwolf must be stopped so you can run it interactively and see the audio level display.

```bash
sudo systemctl stop direwolf
# If linbpq is active, stop it too (it connects to Direwolf):
sudo systemctl stop linbpq
```

## 3. Set initial ALSA levels

Start with conservative levels before fine-tuning:

```bash
# RX (capture from radio → Pi): start at 80%
amixer -c Device set Capture 80%

# TX (playback from Pi → radio): start at 50%
amixer -c Device set Speaker 50%
```

Note: The exact control names may vary. Run `amixer -c Device scontrols` to see what's available. Common names are `Capture`, `Mic`, `Speaker`, `Playback`, or `PCM`.

## 4. Tune RX audio level

Run Direwolf interactively to see the audio level display:

```bash
sudo -u direwolf direwolf -t 0 -c /home/direwolf/direwolf.conf
```

Direwolf prints a line for each received packet showing the audio level. Between packets, it periodically displays the input level. Look for output like:

```
PRIOR: audio level = 35(21/15)
```

The first number (35) is the overall level. Target: **25–50**. Guidelines:

| Level | Meaning | Action |
|-------|---------|--------|
| < 10 | Too quiet — signal buried in noise | Increase Capture |
| 10–25 | Low but may decode strong signals | Consider increasing |
| **25–50** | **Good range for reliable decoding** | **Leave it** |
| 50–75 | Hot — works but approaching clipping | Consider decreasing |
| > 75 | Clipping — distorted, missed decodes | Decrease Capture |

Adjust in 5–10% increments (in a separate terminal):

```bash
# Too quiet:
amixer -c Device set Capture 90%

# Too hot:
amixer -c Device set Capture 60%
```

If there's no packet traffic on frequency, have someone transmit a test packet from another station, or use `arecord` to verify audio is flowing at all:

```bash
# Record 5 seconds of RX audio
arecord -c 1 -r 48000 -f S16_LE -d 5 -D plughw:CARD=Device,DEV=0 /tmp/rx_test.wav

# Play it back through the Pi's speakers/headphones to verify
aplay /tmp/rx_test.wav
```

## 5. Tune TX audio level

TX tuning requires monitoring your transmitted signal on a second receiver.

With Direwolf still running interactively, send a test beacon:

```bash
# In a separate terminal, use the beacon command:
beacon -c W9CPZ-7 -d "CQ" -s ax0 "audio level test"
```

Or trigger a UI beacon from Direwolf's config if one is defined.

On your monitoring radio/SDR, listen for:

| Symptom | Meaning | Action |
|---------|---------|--------|
| No audio / very faint | TX level too low | Increase Speaker/Playback |
| Clean, moderate audio | Correct level | Leave it |
| Distorted, buzzy, splatter on adjacent frequencies | TX level too hot | Decrease Speaker/Playback |

Adjust in 5–10% increments:

```bash
# Too quiet:
amixer -c Device set Speaker 65%

# Distorted:
amixer -c Device set Speaker 40%
```

A typical good starting point for the DigiRig is **50–70% playback**. If your radio has an ALC (automatic level control) meter, the needle should barely move — any significant ALC activity means the audio is too hot.

## 6. Persist ALSA settings

Once levels are correct, save them so they survive reboots:

```bash
sudo alsactl store
```

This writes to `/var/lib/alsa/asound.state`. The `alsa-restore.service` (ships with Debian) loads these settings at boot.

Verify the save:

```bash
# Should show your card's mixer state
sudo alsactl -f /var/lib/alsa/asound.state store
cat /var/lib/alsa/asound.state | grep -A2 Device
```

## 7. Restart services

```bash
# Stop the interactive Direwolf session (Ctrl-C)
# Then start the services back up:
sudo systemctl start direwolf

# Wait a moment for Direwolf to initialize, then:
sudo systemctl start linbpq
```

Verify everything came back:

```bash
systemctl is-active direwolf linbpq
journalctl -u direwolf -n 10 --no-pager
journalctl -u linbpq -n 10 --no-pager
```

## Troubleshooting

**No audio device "Device" found:**
- Check `lsusb` — the DigiRig should show as a CP2102 UART and a USB Audio device
- Try unplugging and replugging the DigiRig
- Check `dmesg | tail -20` for USB enumeration errors

**Direwolf shows audio level = 0 constantly:**
- Verify the radio is receiving (tune to an active frequency)
- Check the cable between radio and DigiRig
- Try `arecord` to test the audio path independently of Direwolf

**Packets are heard but not decoded:**
- Audio may be too hot (clipping) or too quiet
- Try setting Capture to 50% and working up
- Check that MODEM is set to 1200 for VHF packet

**TX keys the radio but no audio is transmitted:**
- Verify Speaker/Playback level is non-zero
- Test with `speaker-test -D plughw:CARD=Device,DEV=0 -c 1 -f 1000 -t sine -l 1`
- Check the DigiRig audio cable connection to the radio
