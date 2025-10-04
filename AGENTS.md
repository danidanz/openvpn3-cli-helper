# Repository Guidelines

## Project Structure & Module Organization
- Root contains `ovctl` (Bash CLI) and example configs: `ovpn-dev.ovpn`, `ovpn-live.ovpn`.
- Keep executable scripts at the root or in `scripts/` (create if needed). Place sample configs in `configs/` if adding more.
- Do not commit secrets; `.ovpn` files here are examples only.

## Build, Test, and Development Commands
- Run locally: `./ovctl <config.ovpn> -t` (status), `-s` (start), `-p` (pause), `-r` (resume), `-d` (disconnect), `-k` (kill all).
- Lint script: `shellcheck ovctl`.
- Requirements: `openvpn3` CLI installed and accessible in `PATH`.

## Coding Style & Naming Conventions
- Language: Bash (bash 4+). Start scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Indentation: 2 spaces; no hard tabs.
- Functions: `snake_case` (e.g., `status_cfg`, `kill_all_cfg`); helpers prefixed with `_`.
- Prefer `awk`, `mapfile`, and pipes over complex parameter parsing; quote all variables; avoid `eval`.
- Update usage text in `ovctl` when adding flags or behavior.

## Testing Guidelines
- Static checks: `shellcheck ovctl` should pass with no errors.
- Manual smoke tests (requires VPN service):
  - `./ovctl ovpn-dev.ovpn -s` then `-t` should show Connected/Paused/Unknown appropriately.
  - `./ovctl ovpn-dev.ovpn -k` should disconnect all matching sessions.
- Optional: add Bats tests under `tests/` for argument parsing and text parsing helpers by stubbing `openvpn3` output.

## Commit & Pull Request Guidelines
- Commits: imperative mood, concise scope. Example: `feat(ovctl): add -k to disconnect all sessions`.
- PRs: include description, commands used, before/after behavior, and any screenshots or logs of `-t` output.
- Link related issues. Update docs and usage examples when behavior changes.

## Security & Configuration Tips
- Never commit real credentials, keys, or private endpoints.
- Treat `.ovpn` files as samples; redact sensitive data before sharing logs.
- Validate user input; avoid leaking paths or IPs in unexpected outputs.
