# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Tools and configuration for managing radio-related Raspberry Pis. The first and currently only concern is an Ansible project under `ansible/` that manages:

- **marconi** — GPS-disciplined NTP server. Debian 12 (bookworm).
- **aloha** — AX.25 / NET/ROM / BBS node, currently running Dire Wolf as a software TNC with a DigiRig USB audio+serial interface. Debian 13 (trixie). **The rest of the packet radio stack (AX.25 tools, NET/ROM, BBS) is explicitly deferred** — do not add those tasks until asked.

Do not assume both hosts are on the same Debian release — they're not. Gate distro-specific vars on `ansible_facts['distribution_release']` (e.g. the `direwolf` role derives its backports suite name this way).

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
make lint    # uv run ansible-lint (also runs syntax-check on every discovered playbook)
make test    # run every tests/*.yml assert playbook
make check   # lint + test — the preferred pre-commit gate
```

`make check` also runs automatically via a `PostToolUse` hook (`.claude/settings.json`) whenever Claude edits a `*.yml`/`*.yaml`/`*.j2`/`Makefile`/`*.cfg` file under `ansible/`. You don't need to invoke it manually after edits — but do run it before committing if you've been editing outside Claude.

### Verifying changes against a real host

`make check` covers lint + offline assert playbooks, but it can't catch problems that only show up when Ansible talks to a real host (modules that probe system state, missing packages, ordering issues). Before declaring a role "done", dry-run it against the target:

```sh
uv run ansible-playbook playbooks/<host>.yml --check --diff
```

Read the `--diff` output to confirm the rendered templates / package lists / handler notifications match what you expected. Treat an unexpected `changed` or a `failed` line as a real defect, not dry-run noise.

**Check-mode gotchas** (all have real fixes already applied in `roles/direwolf/`):

- *New systemd service.* If a role installs a unit and then tries to `enable`/`start` it in the same run, the enable/start (and any `Restart <service>` handler) will fail in `--check` because the unit file isn't actually written to disk. Guard those tasks/handlers with `when: not ansible_check_mode`.
- *New apt repo → package install.* Enabling a repo with `deb822_repository` and immediately installing a package from it (especially via `default_release:`) fails in check mode because the repo was only "pretend" added and apt can't validate the release. Guard the install with `when: not ansible_check_mode`; the deb822 diff above still shows the intended change.
- *Modules with Python library prerequisites.* `deb822_repository` needs `python3-debian` installed on the target to run *even in check mode*. Install the prereq with a dedicated `apt:` task marked `check_mode: false` so it actually runs during dry runs — otherwise the chain fails before it can show you anything. Use `check_mode: false` sparingly and only for side-effect-free prereqs like this one.

Only run the playbook without `--check` after the dry run looks right — and per the "confirm before remote access" rule, confirm with the operator before doing so.

When adding deps: Python → edit `pyproject.toml`, `uv sync`. Galaxy → edit `requirements.yml`, re-run `make bootstrap`.

### Inventory & connection

`inventory.yml` lists hosts as bare aliases (`marconi`, `aloha`) with no connection vars. User/hostname/key are resolved by the operator's `~/.ssh/config` — do not hardcode them in inventory or host_vars.

### Structure conventions

- `site.yml` is the top-level entrypoint applying the `common` role to the `radio_pis` group.
- `playbooks/ping.yml` is for connectivity checks.
- `playbooks/marconi.yml` applies `common` + `gps_ntp`. `playbooks/aloha.yml` applies `common` + `direwolf`.
- `roles/common/` is a minimal placeholder (only `gather_subset: min`). Grow it for things that apply to all radio pis; create new roles for host-specific functionality rather than piling onto `common`.
- `roles/gps_ntp/` reproduces marconi's Stratum 1 setup: chrony + gpsd + PPS via `dtoverlay=pps-gpio,gpiopin=4` on `/dev/pps0`, NMEA over `/dev/ttyAMA0` into chrony SHM unit 2. Boot-config changes only take effect after a reboot — the role prints a warning via handler rather than auto-rebooting. All tunables (offset, allowed networks, GPIO pin) live in `defaults/main.yml`; per-host overrides go in `host_vars/`.
- `roles/direwolf/` runs Dire Wolf as a systemd-managed software TNC on aloha. The role enables `trixie-backports` via `deb822_repository` and installs the backported `direwolf` package (currently 1.8.1), pinned with `default_release`. This is the only supported upgrade path for newer Dire Wolf on Debian stable — don't build from source. All direwolf.conf directives (ADEVICE, MYCALL, PTT, AGW/KISS ports, IGTXLIMIT) are variables in `defaults/main.yml`; the call sign is overridden in `host_vars/aloha.yml`. The config template is stripped of the upstream sample's commentary — keep it that way.
- `host_vars/marconi.yml` records the hand-calibrated `gps_ntp_nmea_offset`. `host_vars/aloha.yml` sets `direwolf_mycall`. `group_vars/radio_pis.yml` is an empty placeholder.
- `tests/` holds ansible-native assert playbooks that run offline: `boot_regex.yml` exercises the lineinfile regexes from `roles/gps_ntp/tasks/boot.yml`, and `direwolf_conf.yml` renders `roles/direwolf/templates/direwolf.conf.j2` and asserts required directives are present and Windows-only tokens are absent. Add new test playbooks here — `make test` globs `tests/*.yml` so they wire in automatically.

### ansible.cfg notes

`stdout_callback = default` with `[callback_default] result_format = yaml` — the older `community.general.yaml` callback was removed in community.general 12.0, so don't re-add it.

## Conventions

- Makefile stays minimal: only targets that wrap multi-step workflows or non-obvious commands. Don't add a Make target that's a thin wrapper around one short command — document the raw `uv run ...` invocation in the README instead.
- Don't modify `legacy/` — it's a frozen historical archive.
