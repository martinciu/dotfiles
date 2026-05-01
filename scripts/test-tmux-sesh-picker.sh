#!/usr/bin/env bash
# Smoke tests for the <prefix> t sesh-picker wrapper.
#
# Verifies popup height math:
#   H = max(MIN, count + BUFFER), clamped above by floor(client_height * MAX_PCT/100).
#   On `sesh list` failure, H = DEFAULT (still clamped above).
#
# Strategy: prepend a tempdir with fake `sesh` and `tmux` shims to PATH;
# run the wrapper; the fake `tmux display-popup` writes its `-h` arg to a
# capture file; assert against expected values.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$REPO/.config/tmux/bin/tmux-sesh-picker"

pass=0
fail=0
fail_msgs=()

setup_shims() {
  local tmpdir="$1"

  cat > "$tmpdir/sesh" <<'EOF'
#!/usr/bin/env bash
# Fake sesh: emit $FAKE_SESH_ITEMS lines, or exit non-zero if FAKE_SESH_FAIL=1.
[[ "${FAKE_SESH_FAIL:-0}" = "1" ]] && exit 1
n=${FAKE_SESH_ITEMS:-0}
for ((i=1; i<=n; i++)); do echo "session-$i"; done
EOF
  chmod +x "$tmpdir/sesh"

  cat > "$tmpdir/tmux" <<'EOF'
#!/usr/bin/env bash
# Fake tmux:
#   - display-message -p '#{client_height}'  -> echo $FAKE_CLIENT_HEIGHT
#   - display-popup ... -h N ...             -> write N to $CAPTURE_FILE
case "$1" in
  display-message)
    echo "${FAKE_CLIENT_HEIGHT:-30}"
    ;;
  display-popup)
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h) echo "$2" > "$CAPTURE_FILE"; shift 2 ;;
        *)  shift ;;
      esac
    done
    ;;
  *)
    echo "fake tmux: unhandled $1" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$tmpdir/tmux"
}

run_case() {
  local label="$1" expected="$2"
  rm -f "$CAPTURE_FILE"
  PATH="$SHIM_DIR:$PATH" "$WRAPPER" >/dev/null 2>&1 || true
  local got
  got="$(cat "$CAPTURE_FILE" 2>/dev/null || echo '(none)')"
  if [[ "$got" == "$expected" ]]; then
    printf 'PASS  %s (h=%s)\n' "$label" "$got"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s — expected h=%s, got h=%s\n' "$label" "$expected" "$got"
    fail=$((fail + 1))
    fail_msgs+=("$label")
  fi
}

# ---------------------------------------------------------------------------
SHIM_DIR="$(mktemp -d)"
trap 'rm -rf "$SHIM_DIR"' EXIT
setup_shims "$SHIM_DIR"
export CAPTURE_FILE="$SHIM_DIR/captured-h"

# Case 1: 0 items → MIN (6) — count+BUFFER=4, clamped up to MIN
export FAKE_CLIENT_HEIGHT=30 FAKE_SESH_ITEMS=0; unset FAKE_SESH_FAIL
run_case "0 items clamps to MIN" 6

# Case 2: 5 items → 5 + BUFFER (4) = 9
export FAKE_SESH_ITEMS=5
run_case "5 items → count+BUFFER" 9

# Case 3: 100 items in 30-row terminal → cap at floor(30*0.8) = 24
export FAKE_SESH_ITEMS=100
run_case "100 items capped to 80% of client height" 24

# Case 4: sesh fails → DEFAULT (15), still under 30-row cap of 24
export FAKE_SESH_FAIL=1
run_case "sesh failure falls back to DEFAULT" 15

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'
  for msg in "${fail_msgs[@]}"; do printf '  - %s\n' "$msg"; done
  exit 1
fi
