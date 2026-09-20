#!/usr/bin/env bash
# Tests for ovctl. No root, no OpenVPN service, no real tunnel required:
# `openvpn3` is stubbed so the parsers are driven with fixed fixture output.
#
# Run: tests/run-tests.sh        (or: bash tests/run-tests.sh)
# Exit 0 = all passed.
#
# These exist mainly to pin the portable-awk path extraction in kill_all_cfg():
# a regression to gawk's 3-arg match() passes on Arch/gawk and dies on mawk,
# which is what Ubuntu and Debian ship as /usr/bin/awk.
set -uo pipefail

OVCTL="${OVCTL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ovctl}"
STUBDIR="$(mktemp -d)"
trap 'rm -rf "$STUBDIR"' EXIT

PASS=0; FAIL=0
ck() { # ck <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then printf 'ok   %s\n' "$1"; PASS=$((PASS+1))
  else printf 'FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}

stub() { # stub: read the fixture from stdin
  cat >"$STUBDIR/openvpn3"
  chmod +x "$STUBDIR/openvpn3"
}

run() { PATH="$STUBDIR:$PATH" "$OVCTL" "$@"; }

echo "# ovctl test suite"
echo "# awk in use: $(awk -W version 2>&1 | head -1)"
echo "# target:     $OVCTL"

# --------------------------------------------------------------------------
echo
echo "## arg handling"
# -h is the FLAG, so it still needs the <config> positional: `ovctl -h` alone exits 2.
OUT="$(run myvpn -h 2>&1)"; EC=$?
ck "-h exits 0" 0 "$EC"
ck "-h prints usage" "Usage: ovctl <config> [-s|-p|-r|-d|-t|-k|-h]" "$(head -1 <<<"$OUT")"

OUT="$(run -h 2>&1)"; EC=$?
ck "-h without config exits 2 (documented shape)" 2 "$EC"

OUT="$(run 2>&1)"; EC=$?
ck "no args exits 2" 2 "$EC"

OUT="$(run onlyconfig.ovpn 2>&1)"; EC=$?
ck "config but no flag exits 2" 2 "$EC"

OUT="$(run myvpn -z 2>&1)"; EC=$?
ck "unknown flag exits 2" 2 "$EC"

# --------------------------------------------------------------------------
echo
echo "## passthrough arguments (-s/-p/-r/-d)"
stub <<'STUB'
#!/usr/bin/env bash
echo "ARGV: $*"
exit 0
STUB
ck "-s invokes session-start -c" \
   "ARGV: session-start -c myvpn" "$(run myvpn -s 2>&1)"
ck "-p invokes session-manage --pause" \
   "ARGV: session-manage --config myvpn --pause" "$(run myvpn -p 2>&1)"
ck "-r invokes session-manage --resume" \
   "ARGV: session-manage --config myvpn --resume" "$(run myvpn -r 2>&1)"
ck "-d invokes session-manage --disconnect" \
   "ARGV: session-manage --config myvpn --disconnect" "$(run myvpn -d 2>&1)"
ck "-s passes a raw .ovpn path through" \
   "ARGV: session-start -c /tmp/a b.ovpn" "$(run "/tmp/a b.ovpn" -s 2>&1)"

# --------------------------------------------------------------------------
echo
echo "## -t status: connected (labels 'Session path' + 'Status')"
stub <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  sessions-list) cat <<'EOF'
Session path: /net/openvpn/v3/sessions/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Config name: myvpn
Owner: danisatria
Device: tun0
Status: Connected
Remote: 203.0.113.9:1194
IPv4 address: 10.8.0.42
EOF
;;
esac
exit 1
STUB
OUT="$(run myvpn -t 2>&1)"; EC=$?
ck "connected exit code 0" 0 "$EC"
ck "connected state" "  State        : Connected" "$(grep '^  State' <<<"$OUT")"
ck "connected session path" \
   "  Session path : /net/openvpn/v3/sessions/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$(grep '^  Session path' <<<"$OUT")"
ck "connected remote" "  Remote       : 203.0.113.9:1194" "$(grep '^  Remote' <<<"$OUT")"
ck "connected ip" "  IP           : 10.8.0.42" "$(grep '^  IP' <<<"$OUT")"

# --------------------------------------------------------------------------
echo
echo "## -t status: paused (label 'Path' instead of 'Session path')"
stub <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  sessions-list) cat <<'EOF'
Path: /net/openvpn/v3/sessions/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
Config name: myvpn
Owner: danisatria
Status: Paused
EOF
;;
esac
exit 1
STUB
OUT="$(run myvpn -t 2>&1)"; EC=$?
ck "paused exit code 10" 10 "$EC"
ck "paused state text" "  State        : Paused (VPN session suspended)" "$(grep '^  State' <<<"$OUT")"
ck "paused path parsed from 'Path' label" \
   "  Session path : /net/openvpn/v3/sessions/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "$(grep '^  Session path' <<<"$OUT")"

# --------------------------------------------------------------------------
echo
echo "## -t status: no session / no state line"
stub <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  sessions-list) echo "No sessions available"; exit 0 ;;
esac
exit 1
STUB
OUT="$(run myvpn -t 2>&1)"; EC=$?
ck "no session exit code 20" 20 "$EC"
ck "no session message" "myvpn: no active session." "$OUT"

# A matched block with no Status/State line must NOT be guessed as connected.
stub <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  sessions-list) cat <<'EOF'
Session path: /net/openvpn/v3/sessions/cccccccccccccccccccccccccccccccc
Config name: myvpn
Owner: danisatria
EOF
;;
esac
exit 1
STUB
OUT="$(run myvpn -t 2>&1)"; EC=$?
ck "stateless block reports (unknown)" "  State        : (unknown)" "$(grep '^  State' <<<"$OUT")"
ck "stateless block exit code 20" 20 "$EC"

# --------------------------------------------------------------------------
echo
echo "## -k kill all: selects only this config, both path labels"
stub <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  sessions-list) cat <<'EOF'
Session path: /net/openvpn/v3/sessions/11111111111111111111111111111111
Config name: myvpn
Owner: danisatria
Status: Connected

Session path: /net/openvpn/v3/sessions/22222222222222222222222222222222
Config name: othervpn
Owner: danisatria
Status: Connected

Path: /net/openvpn/v3/sessions/33333333333333333333333333333333
Config name: myvpn
Owner: danisatria
Status: Connected
EOF
;;
  session-manage) echo "MANAGE $*"; exit 0 ;;
esac
exit 1
STUB
OUT="$(run myvpn -k 2>&1)"; EC=$?
ck "-k exit code 0" 0 "$EC"
ck "-k count line" "myvpn: killing 2 session(s)..." "$(grep killing <<<"$OUT")"
ck "-k disconnects by session path" 2 "$(grep -c -- '--session-path' <<<"$OUT")"
ck "-k hit session 1111" 1 "$(grep -c 'MANAGE .*11111111111111111111111111111111' <<<"$OUT")"
ck "-k hit session 3333 (Path label)" 1 "$(grep -c 'MANAGE .*33333333333333333333333333333333' <<<"$OUT")"
ck "-k did NOT touch other config 2222" 0 "$(grep -c '22222222222222222222222222222222' <<<"$OUT")"

# --------------------------------------------------------------------------
echo
echo "## -k kill all: nothing matching"
stub <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  sessions-list) cat <<'EOF'
Session path: /net/openvpn/v3/sessions/44444444444444444444444444444444
Config name: othervpn
Status: Connected
EOF
;;
  session-manage) echo "MANAGE SHOULD NOT RUN"; exit 0 ;;
esac
exit 1
STUB
OUT="$(run myvpn -k 2>&1)"; EC=$?
ck "-k none exit code 0" 0 "$EC"
ck "-k none message" "myvpn: no sessions to kill." "$OUT"
ck "-k none runs no disconnect" 0 "$(grep -c MANAGE <<<"$OUT")"

# --------------------------------------------------------------------------
echo
echo "## portable awk (the whole point of this suite)"
echo "# awk in use: $(readlink -f "$(command -v awk)")"
# Strip comment lines first: the ovctl comments mention the gawk extension by name,
# so a raw grep matches its own warning.
CODE_NC="$(grep -v '^[[:space:]]*#' "$OVCTL")"
ck "no gawk 3-arg match() in ovctl code" 0 "$(grep -cE 'match\([^)]*,[^)]*,' <<<"$CODE_NC")"
ck "no --show probe left in ovctl code" 0 "$(grep -c -- '--show' <<<"$CODE_NC")"
if command -v mawk >/dev/null 2>&1; then
  echo "ok   mawk present - re-running -k under mawk"
  ck "kill_all_cfg parse works under mawk" "myvpn: no sessions to kill." \
     "$(PATH="$STUBDIR:$PATH" "$OVCTL" myvpn -k 2>&1)"
else
  echo "skip mawk not installed on this host (Ubuntu/Debian default awk)"
fi

echo
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
