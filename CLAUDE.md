# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Tools and configuration for managing radio-related Raspberry Pis. The first and currently only concern is an Ansible project under `ansible/` that manages:

- **marconi** — GPS-disciplined NTP server (existing).
- **aloha** — Fresh Pi destined to become an AX.25 / NET/ROM / BBS node. Under initial management only; **packet radio configuration is explicitly deferred** — do not add AX.25/NET/ROM/BBS tasks until asked.

Top-level layout: `ansible/` (active), `legacy/` (archived ~2015 scripts, do not touch), `docs/` and `scripts/` (placeholders).

## Ansible project

All commands below run from `ansible/`.

### Toolchain

The control environment is managed by `uv` (Astral). Python deps are pinned in `pyproject.toml` + `uv.lock`; Galaxy collections/roles are pinned in `requirements.yml`. Both are installed by:

```sh
make bootstrap   # uv sync + ansible-galaxy install -r requirements.yml
```

Run playbooks via `uv run` (or `source .venv/bin/activate` once):

```sh
uv run ansible-playbook playbooks/ping.yml
uv run ansible-playbook site.yml
make lint   # uv run ansible-lint
```

When adding deps: Python → edit `pyproject.toml`, `uv sync`. Galaxy → edit `requirements.yml`, re-run `make bootstrap`.

### Inventory & connection

`inventory.yml` lists hosts as bare aliases (`marconi`, `aloha`) with no connection vars. User/hostname/key are resolved by the operator's `~/.ssh/config` — do not hardcode them in inventory or host_vars.

### Structure conventions

- `site.yml` is the top-level entrypoint applying the `common` role to the `radio_pis` group.
- `playbooks/ping.yml` is for connectivity checks.
- `playbooks/{marconi,aloha}.yml` are host-specific plays; currently stubs that apply `common` with TODO comments.
- `roles/common/` is a minimal placeholder (only `gather_subset: min`). Grow it for things that apply to all radio pis; create new roles for host-specific functionality rather than piling onto `common`.
- `group_vars/radio_pis.yml`, `host_vars/{marconi,aloha}.yml` exist as empty placeholders.

### ansible.cfg notes

`stdout_callback = default` with `[callback_default] result_format = yaml` — the older `community.general.yaml` callback was removed in community.general 12.0, so don't re-add it.

## Conventions

- Makefile stays minimal: only targets that wrap multi-step workflows or non-obvious commands. Don't add a Make target that's a thin wrapper around one short command — document the raw `uv run ...` invocation in the README instead.
- Don't modify `legacy/` — it's a frozen historical archive.
