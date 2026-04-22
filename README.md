# RadioPi

Tools and configuration for managing radio-related Raspberry Pis.

## Layout

- `ansible/` — Ansible project for managing the radio Pis. See [`ansible/README.md`](ansible/README.md).
- `legacy/` — Archived scripts from the original (~2015) incarnation of this repo. Unmaintained, kept for reference.
- `portable/` — Standalone macOS setup for portable packet radio with an HT + AIOC. See [`portable/README.md`](portable/README.md).
- `docs/` — Notes and documentation (TBD).
- `scripts/` — Helper scripts (TBD).

## Hosts

- **marconi** — GPS-disciplined NTP server.
- **aloha** — Packet radio node running Dire Wolf (software TNC) and LinBPQ (AX.25 / NET/ROM / BBS).
- **macOS laptop** — Field-portable packet setup using Dire Wolf + AIOC on 145.050 MHz. Not Ansible-managed.
