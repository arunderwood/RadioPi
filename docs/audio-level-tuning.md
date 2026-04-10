# Audio Level Tuning — Direwolf + DigiRig Mobile

Set correct audio levels between Direwolf on aloha and the radio via the DigiRig Mobile USB interface. The radio should not need adjustment — only the Pi-side ALSA mixer controls.

No services need to be stopped. Direwolf logs audio levels to journalctl and LinBPQ's periodic NODES/ID broadcasts provide TX test signals.

## 1. Verify the DigiRig

```bash
amixer -c Device scontrols
```

Should list Capture and Speaker (or Playback/PCM) controls. If "Device" isn't found, check `lsusb` and `dmesg | tail -20`.

## 2. Set initial ALSA levels

```bash
amixer -c Device set Capture 80%
amixer -c Device set Speaker 50%
```

Control names vary by card — check `amixer -c Device scontrols` for yours.

## 3. Tune RX

Tail the Direwolf journal while the radio receives:

```bash
journalctl -f -u direwolf
```

Direwolf periodically logs the input level:

```
audio level = 35(21/15)
```

The first number is the overall level. Target **25–50**.

| Level | Action |
|-------|--------|
| < 10 | Increase Capture — signal is in the noise |
| **25–50** | **Good — leave it** |
| > 75 | Decrease Capture — clipping, missed decodes |

Adjust in a second terminal:

```bash
amixer -c Device set Capture 90%   # too quiet
amixer -c Device set Capture 60%   # too hot
```

If no traffic is on frequency, verify the audio path with `arecord`:

```bash
arecord -c 1 -r 48000 -f S16_LE -d 5 -D plughw:CARD=Device,DEV=0 /tmp/rx_test.wav
aplay /tmp/rx_test.wav
```

## 4. Tune TX

LinBPQ automatically transmits NODES broadcasts and ID beacons — monitor these on a second radio or SDR.

| Symptom | Action |
|---------|--------|
| No audio / very faint | Increase Speaker |
| Clean, moderate audio | Leave it |
| Distorted, splatter on adjacent freqs | Decrease Speaker |

```bash
amixer -c Device set Speaker 65%   # too quiet
amixer -c Device set Speaker 40%   # distorted
```

If the radio has an ALC meter, it should barely move. Significant ALC activity means audio is too hot.

## 5. Save and verify

```bash
sudo alsactl store
```

This writes to `/var/lib/alsa/asound.state`. Debian's `alsa-restore.service` loads it at boot.

Confirm Direwolf is still happy:

```bash
journalctl -u direwolf -n 10 --no-pager
journalctl -u linbpq -n 10 --no-pager
```
