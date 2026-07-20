#!/opt/homebrew/bin/bash
# Smoke tests for tmux-phone-twin against a real, socket-isolated tmux
# server — session grouping and options are real tmux behavior; mocking
# them would test the mock. A PATH wrapper pins bare `tmux` to the socket.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO/.config/tmux/bin/tmux-phone-twin"
SOCK="phone-twin-test-$$"
TMUX_BIN="$(command -v tmux)"

WRAP=$(mktemp -d)
cat > "$WRAP/tmux" <<EOF
#!/opt/homebrew/bin/bash
exec "$TMUX_BIN" -L "$SOCK" -f /dev/null "\$@"
EOF
chmod +x "$WRAP/tmux"
export PATH="$WRAP:$PATH"

cleanup() { tmux kill-server 2>/dev/null || true; rm -rf "$WRAP"; }
trap cleanup EXIT

pass=0; fail=0; fail_msgs=()
check() {
  local name="$1"; shift
  if "$@"; then printf 'PASS  %s\n' "$name"; pass=$((pass+1))
  else printf 'FAIL  %s\n' "$name"; fail=$((fail+1)); fail_msgs+=("$name"); fi
}
fresh() { tmux kill-server 2>/dev/null || true; sleep 0.2; }

# Test 1: target exists, no twin -> twin created, grouped, bar-less, marked
test_create() {
  fresh; tmux new-session -d -s notes
  local out; out=$("$SCRIPT" notes) || { echo "  script failed"; return 1; }
  [ "$out" = notes-phone ] || { echo "  expected notes-phone, got: $out"; return 1; }
  tmux has-session -t =notes-phone 2>/dev/null || { echo "  twin missing"; return 1; }
  [ "$(tmux display-message -p -t notes-phone '#{session_group}')" = notes ] \
    || { echo "  not grouped with notes"; return 1; }
  [ "$(tmux show-option -t notes-phone -v status)" = off ] \
    || { echo "  status not off"; return 1; }
  [ "$(tmux show-option -t notes-phone -qv @phone_twin)" = 1 ] \
    || { echo "  marker missing"; return 1; }
  [ "$(tmux show-option -t notes-phone -qv destroy-unattached)" != on ] \
    || { echo "  destroy-unattached must NOT be set at creation"; return 1; }
}
check "target exists -> grouped bar-less marked twin" test_create

# Test 2: idempotent -> same name, twin reused (created-at unchanged)
test_idempotent() {
  fresh; tmux new-session -d -s notes
  "$SCRIPT" notes >/dev/null
  local created; created=$(tmux display-message -p -t notes-phone '#{session_created}')
  local out; out=$("$SCRIPT" notes)
  [ "$out" = notes-phone ] || { echo "  expected notes-phone, got: $out"; return 1; }
  [ "$(tmux display-message -p -t notes-phone '#{session_created}')" = "$created" ] \
    || { echo "  twin was recreated, not reused"; return 1; }
}
check "second run reuses the twin" test_idempotent

# Test 3: stale ungrouped notes-phone (historical resurrect artifact) -> replaced
test_stale_killed() {
  fresh; tmux new-session -d -s notes
  tmux new-session -d -s notes-phone          # ungrouped impostor
  tmux set-option -t notes-phone @stale 1     # canary (set-option rejects =)
  "$SCRIPT" notes >/dev/null
  [ "$(tmux show-option -t notes-phone -qv @stale)" != 1 ] \
    || { echo "  stale twin survived"; return 1; }
  [ "$(tmux display-message -p -t notes-phone '#{session_group}')" = notes ] \
    || { echo "  replacement not grouped"; return 1; }
}
check "stale ungrouped twin killed and replaced" test_stale_killed

# Test 4: target is itself a twin -> printed as-is, no nesting
test_twin_of_twin() {
  fresh; tmux new-session -d -s notes
  "$SCRIPT" notes >/dev/null
  local out; out=$("$SCRIPT" notes-phone)
  [ "$out" = notes-phone ] || { echo "  expected notes-phone, got: $out"; return 1; }
  ! tmux has-session -t =notes-phone-phone 2>/dev/null \
    || { echo "  nested twin created"; return 1; }
}
check "twin-of-twin guard: twin returned as-is" test_twin_of_twin

# Test 5: missing target -> non-zero exit, empty stdout
test_missing_target() {
  fresh
  local out rc=0; out=$("$SCRIPT" ghost 2>/dev/null) || rc=$?
  [ "$rc" -ne 0 ] || { echo "  expected non-zero exit"; return 1; }
  [ -z "$out" ] || { echo "  expected empty stdout, got: $out"; return 1; }
}
check "missing target -> non-zero, silent stdout" test_missing_target

# Test 6: slashed target (s-convention name) -> twin named verbatim
test_slashed_target() {
  fresh; tmux new-session -d -s dotfiles/366-x
  local out; out=$("$SCRIPT" dotfiles/366-x)
  [ "$out" = dotfiles/366-x-phone ] || { echo "  got: $out"; return 1; }
  [ "$(tmux display-message -p -t dotfiles/366-x-phone '#{session_group}')" = dotfiles/366-x ] \
    || { echo "  not grouped"; return 1; }
}
check "slashed session name handled" test_slashed_target

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'; for m in "${fail_msgs[@]}"; do printf '  - %s\n' "$m"; done
  exit 1
fi
