# RadioPi Ansible

Ansible project for managing the radio Raspberry Pis.

## Prerequisites

- [`uv`](https://docs.astral.sh/uv/) installed.
- SSH access to each host via short alias (`marconi`, `aloha`). Connection details (user, hostname, key) are expected to be resolved by `~/.ssh/config`.

## Bootstrap

From this directory:

```sh
make bootstrap
```

That runs `uv sync` (pinned Python deps from `pyproject.toml` / `uv.lock`) and `uv run ansible-galaxy install -r requirements.yml` (Galaxy collections and roles).

## Usage

```sh
uv run ansible-playbook playbooks/ping.yml
uv run ansible-playbook site.yml
```

Or `source .venv/bin/activate` to drop the `uv run` prefix.

## Hosts

- `marconi` — GPS/NTP server (managed).
- `aloha` — Fresh Pi; initial management only. Packet radio (AX.25 / NET/ROM / BBS) configuration deferred.

## Adding dependencies

- Python deps: edit `pyproject.toml`, then `uv sync`.
- Galaxy collections/roles: edit `requirements.yml`, then re-run `make bootstrap`.
