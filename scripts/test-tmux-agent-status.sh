#!/opt/homebrew/bin/bash
# Smoke tests for tmux-agent-status.
#
# Strategy: run the helper with XDG_CACHE_HOME pointed at a throwaway dir
# so the live cache is untouched, then drop fake <session>.status files
# and assert the two-line stdout contract.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO/.config/tmux/bin/tmux-agent-status"

pass=0
fail=0
fail_msgs=()

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then
    pass=$((pass+1))
    echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        want: '$want'")
    echo "  FAIL  $desc"
  fi
}

run_helper() {
  XDG_CACHE_HOME="$1" "$HELPER"
}

echo
echo "tmux-agent-status"
echo "─────────────────"

if [ ! -x "$HELPER" ]; then
  echo "  SKIP — $HELPER not present yet"
else
  # Case 1: cache dir absent.
  sandbox=$(mktemp -d)
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'empty\n0 0 0' "1. cache dir absent → empty"

  # Case 2: cache dir present, no .status files.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'empty\n0 0 0' "2. dir present, no files → empty"

  # Case 3: one done file.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  printf 'done' > "$sandbox/tmux-agent-status/foo.status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'idle\n0 0 1' "3. one done → idle 0 0 1"

  # Case 4: one working file.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  printf 'working' > "$sandbox/tmux-agent-status/foo.status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'working\n0 1 0' "4. one working → working 0 1 0"

  # Case 5: one wait file.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  printf 'wait' > "$sandbox/tmux-agent-status/foo.status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'wait\n1 0 0' "5. one wait → wait 1 0 0"

  # Case 6: mixed: 1 wait, 2 working, 1 done.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  printf 'wait'    > "$sandbox/tmux-agent-status/a.status"
  printf 'working' > "$sandbox/tmux-agent-status/b.status"
  printf 'working' > "$sandbox/tmux-agent-status/c.status"
  printf 'done'    > "$sandbox/tmux-agent-status/d.status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'wait\n1 2 1' "6. mixed wait/working/done → wait 1 2 1"

  # Case 7: mixed: 0 wait, 3 working, 2 done.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  printf 'working' > "$sandbox/tmux-agent-status/a.status"
  printf 'working' > "$sandbox/tmux-agent-status/b.status"
  printf 'working' > "$sandbox/tmux-agent-status/c.status"
  printf 'done'    > "$sandbox/tmux-agent-status/d.status"
  printf 'done'    > "$sandbox/tmux-agent-status/e.status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'working\n0 3 2' "7. no wait, 3 working, 2 done → working 0 3 2"

  # Case 8: lone file containing unknown token.
  sandbox=$(mktemp -d)
  mkdir -p "$sandbox/tmux-agent-status"
  printf 'bogus' > "$sandbox/tmux-agent-status/foo.status"
  out=$(run_helper "$sandbox")
  assert_eq "$out" $'empty\n0 0 0' "8. unknown token only → empty"
fi

echo
echo "──────────────────────────────"
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n\n' "${fail_msgs[@]}"
  exit 1
fi
