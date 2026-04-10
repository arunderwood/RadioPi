# RadioPi

Tools and configuration for managing radio-related Raspberry Pis.

## Layout

- `ansible/` — Ansible project for managing the radio Pis. See [`ansible/README.md`](ansible/README.md).
- `legacy/` — Archived scripts from the original (~2015) incarnation of this repo. Unmaintained, kept for reference.
- `docs/` — Notes and documentation (TBD).
- `scripts/` — Helper scripts (TBD).

## Hosts

- **marconi** — GPS-disciplined NTP server.
- **aloha** — Packet radio node running Dire Wolf (software TNC) and LinBPQ (AX.25 / NET/ROM / BBS).
