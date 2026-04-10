# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Tools and configuration for managing radio-related Raspberry Pis. The first and currently only concern is an Ansible project under `ansible/` that manages:

- **marconi** — GPS-disciplined NTP server. Debian 12 (bookworm).
- **aloha** — AX.25 / NET/ROM node running Dire Wolf as a software TNC with a DigiRig USB audio+serial interface. Debian 13 (trixie). **BBS software (URONode / FBB / JNOS / LinBPQ / …) is still explicitly deferred** — do not add those tasks until asked; the operator wants to do discovery first.

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
- `playbooks/marconi.yml` applies `common` + `gps_ntp`. `playbooks/aloha.yml` applies `common` + `direwolf` + either `ax25` (kernel AX.25) or `linbpq` (LinBPQ node/BBS) — the two are substitutable, never both.
- `roles/common/` is a minimal placeholder (only `gather_subset: min`). Grow it for things that apply to all radio pis; create new roles for host-specific functionality rather than piling onto `common`.
- `roles/gps_ntp/` reproduces marconi's Stratum 1 setup: chrony + gpsd + PPS via `dtoverlay=pps-gpio,gpiopin=4` on `/dev/pps0`, NMEA over `/dev/ttyAMA0` into chrony SHM unit 2. Boot-config changes only take effect after a reboot — the role prints a warning via handler rather than auto-rebooting. All tunables (offset, allowed networks, GPIO pin) live in `defaults/main.yml`; per-host overrides go in `host_vars/`.
- `roles/direwolf/` runs Dire Wolf as a systemd-managed software TNC on aloha. The role enables `trixie-backports` via `deb822_repository` and installs the backported `direwolf` package (currently 1.8.1), pinned with `default_release`. This is the only supported upgrade path for newer Dire Wolf on Debian stable — don't build from source. All direwolf.conf directives (ADEVICE, MYCALL, PTT, AGW/KISS ports, IGTXLIMIT) are variables in `defaults/main.yml`; the call sign is overridden in `host_vars/aloha.yml`. The config template is stripped of the upstream sample's commentary — keep it that way. The systemd unit starts direwolf with `-p`, which creates a pty and symlinks `/tmp/kisstnc` — this is how the `ax25` role hands KISS frames to the kernel. `PrivateTmp` stays off so the symlink is visible to other services.
- `roles/ax25/` layers kernel AX.25 + NET/ROM on top of direwolf's `/tmp/kisstnc` pty. Installs `ax25-tools` + `ax25-apps` from trixie stable (no backports needed), loads the `ax25` and `netrom` kernel modules, renders `/etc/ax25/{axports,nrports,nrbroadcast}` from templates, and manages `kissattach.service` + `netromd.service` as systemd units ordered after `direwolf.service`. `kissattach.service` uses an `ExecStartPre` shell loop to wait for `/tmp/kisstnc` before attaching, since direwolf may not have created the symlink by the time systemd starts the dependent unit. NET/ROM lives behind `ax25_netrom_enabled: true` in defaults so the role stays useful for AX.25-only setups. The AX.25 callsign and NET/ROM alias are per-host in `host_vars/aloha.yml`. Tuning directives (`TXDELAY` / `PERSIST` / `SLOTTIME` / `TXTAIL` / `FIX_BITS`) are **not** set in direwolf.conf — the Debian-shipped direwolf sample omits them entirely and the defaults are fine for VHF 1200 baud. Revisit only if on-air testing shows problems.
- `roles/linbpq/` runs LinBPQ as a packet radio node + BBS on aloha. LinBPQ has its own AX.25 and NET/ROM implementation — it does **not** use the kernel AX.25 stack. It connects directly to Direwolf's KISS TCP port (8001). The `linbpq` and `ax25` roles are **substitutable** — both provide "packet networking on top of Direwolf" but via different implementations. When `linbpq` is active, it defensively stops kissattach/netromd if present from a prior `ax25` deployment. LinBPQ is installed from a precompiled arm64 binary (`pilinbpq` from G8BPQ) since the OARC apt repo doesn't publish arm64 packages for trixie. The binary lives in `/opt/linbpq/` alongside `bpq32.cfg` (LinBPQ reads config from its working directory, not `/etc/`). The `bpq32.cfg` template is intentionally minimal — only verified LinBPQ directives are included. Telnet/HTTP management, IDMSG/BTEXT broadcasts, and advanced tuning should be added incrementally after verifying the base config works.
- `host_vars/marconi.yml` records the hand-calibrated `gps_ntp_nmea_offset`. `host_vars/aloha.yml` sets `direwolf_mycall`, kernel AX.25 vars (`ax25_callsign`, etc.), and LinBPQ vars (`linbpq_nodecall`, etc.) — only one set is active depending on which role is in the playbook. `group_vars/radio_pis.yml` is an empty placeholder.
- `tests/` holds ansible-native assert playbooks that run offline: `boot_regex.yml` exercises the lineinfile regexes from `roles/gps_ntp/tasks/boot.yml`, `direwolf_conf.yml` renders `roles/direwolf/templates/direwolf.conf.j2` and asserts required directives are present and Windows-only tokens are absent, `ax25_conf.yml` renders the axports/nrports/nrbroadcast templates and asserts the expected lines are produced, and `linbpq_conf.yml` renders `bpq32.cfg.j2` and asserts required BPQ directives are present. Add new test playbooks here — `make test` globs `tests/*.yml` so they wire in automatically.

### ansible.cfg notes

`stdout_callback = default` with `[callback_default] result_format = yaml` — the older `community.general.yaml` callback was removed in community.general 12.0, so don't re-add it.

## Conventions

- Makefile stays minimal: only targets that wrap multi-step workflows or non-obvious commands. Don't add a Make target that's a thin wrapper around one short command — document the raw `uv run ...` invocation in the README instead.
- Don't modify `legacy/` — it's a frozen historical archive.
