ovctl — OpenVPN 3 CLI helper

Overview
- Small Bash wrapper around the OpenVPN 3 Linux CLI (`openvpn3`).
- Provides quick start/pause/resume/disconnect, status with useful fields, and a "kill all" for a given config.

Requirements
- Bash 4+ (`/usr/bin/env bash`)
- `openvpn3` in `PATH` (OpenVPN 3 Linux)

Install
- Copy: `sudo install -m 0755 -o root -g root ovctl /usr/local/bin/ovctl`
- Or symlink (tracks local edits): `sudo ln -sf "$(pwd)/ovctl" /usr/local/bin/ovctl`

Usage
- `ovctl <config.ovpn> [-s|-p|-r|-d|-t|-k|-h]`
  - `-s` start         → `openvpn3 session-start -c <config>`
  - `-p` pause         → `openvpn3 session-manage --config <config> --pause`
  - `-r` resume        → `openvpn3 session-manage --config <config> --resume`
  - `-d` disconnect    → `openvpn3 session-manage --config <config> --disconnect`
  - `-t` status        → shows path/state/remote/IP; exit 0=connected, 10=paused, 20=down
  - `-k` kill all      → disconnect all matching sessions for `<config>`
  - `-h` help

Examples
- Status: `ovctl ovpn-dev.ovpn -t`
- Start: `ovctl ovpn-dev.ovpn -s`
- Pause/Resume: `ovctl ovpn-dev.ovpn -p` then `ovctl ovpn-dev.ovpn -r`
- Disconnect: `ovctl ovpn-dev.ovpn -d`
- Kill all sessions for config: `ovctl ovpn-dev.ovpn -k`

Persistent Configs (OpenVPN 3)
- Import as persistent (recommended):
  - `openvpn3 config-import --persistent --name ovpn-live --path ovpn-live.ovpn`
  - `openvpn3 config-import --persistent --name ovpn-dev  --path ovpn-dev.ovpn`
- List: `openvpn3 configs-list`
- Remove: `openvpn3 config-remove --name ovpn-live`

Notes
- `ovctl` works with raw `.ovpn` paths or with names known to OpenVPN 3.
- For active sessions, `openvpn3 sessions-list` is used; status parsing tolerates minor output variations.

Development
- Lint: `shellcheck ovctl` (should pass with no errors)
- Manual smoke tests (require OpenVPN service):
  - `./ovctl ovpn-dev.ovpn -s` then `./ovctl ovpn-dev.ovpn -t` → expect Connected/Paused/Unknown appropriately
  - `./ovctl ovpn-dev.ovpn -k` → disconnects all sessions for that config
- Optional tests: add Bats tests under `tests/` by stubbing `openvpn3` outputs.

Troubleshooting
- D-Bus errors (e.g., "Could not connect to the D-Bus"):
  - Ensure OpenVPN 3 service/components are installed and available on D-Bus.
  - Verify `openvpn3 configs-list` and `openvpn3 sessions-list` work outside containers/sandboxes.
  - Re-login if the service was just installed; check user session D-Bus availability.
- Ensure `openvpn3` is in `PATH`: `openvpn3 --version`.

Security
- Never commit real credentials, keys, or private endpoints.
- Treat `.ovpn` files as samples only; redact sensitive data before sharing logs.

