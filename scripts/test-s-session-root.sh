#!/usr/bin/env bash
# Tests the @session_root format string used by the <prefix> c binding in
# .config/tmux/tmux.conf. Two arms:
#   1. @session_root set   -> resolves to its value
#   2. @session_root unset -> falls back to pane_current_path
#
# Plus a presence check that tmux.conf actually wires the binding.
#
# Uses an isolated tmux server (-L test-session-root-$$) so no interference
# with the user's running tmux. Tears down via trap on EXIT.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$REPO/.config/tmux/tmux.conf"

# Must match the format string in tmux.conf's `bind c new-window -c …` line.
FMT='#{?#{!=:#{@session_root},},#{@session_root},#{pane_current_path}}'

SOCKET="test-session-root-$$"
T=(tmux -L "$SOCKET")

cleanup() { "${T[@]}" kill-server 2>/dev/null || true; rm -rf "$DIR_A" "$DIR_B"; }
trap cleanup EXIT

pass=0
fail=0
fail_msgs=()

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        want: '$want'")
    echo "  FAIL  $desc"
  fi
}

assert_contains() {
  local hay="$1" needle="$2" desc="$3"
  if printf '%s' "$hay" | grep -q -F -- "$needle"; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        needle not found: '$needle'")
    echo "  FAIL  $desc"
  fi
}

echo
echo "tmux @session_root format string"
echo "────────────────────────────────"

# Use real paths (resolves macOS /var -> /private/var) so display-message
# returns paths in the form we compare against.
DIR_A=$(mktemp -d); DIR_A=$(cd "$DIR_A" && pwd -P)
DIR_B=$(mktemp -d); DIR_B=$(cd "$DIR_B" && pwd -P)

# Bring up an isolated server with one session whose start dir is DIR_A.
"${T[@]}" new-session -d -s s1 -c "$DIR_A"

# Test 1: @session_root set -> resolves to its value.
"${T[@]}" set-option -t s1 @session_root "$DIR_B"
got=$("${T[@]}" display-message -p -t s1 "$FMT")
assert_eq "$got" "$DIR_B" "@session_root set -> format resolves to its value"

# Test 2: @session_root unset -> falls back to pane_current_path.
"${T[@]}" set-option -u -t s1 @session_root
got=$("${T[@]}" display-message -p -t s1 "$FMT")
assert_eq "$got" "$DIR_A" "@session_root unset -> format falls back to pane_current_path"

# Test 3: tmux.conf actually contains the binding using @session_root.
conf=$(cat "$CONF")
assert_contains "$conf" "bind c new-window -c" \
  "tmux.conf has 'bind c new-window -c' (overrides default <prefix> c)"
assert_contains "$conf" "@session_root" \
  "tmux.conf references @session_root (the <prefix> c binding consumes it)"

# Summary
echo
echo "─────────────────"
echo "test-s-session-root.sh passed: $pass"
echo "test-s-session-root.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
