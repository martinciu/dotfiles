#!/usr/bin/env bash
# Smoke tests for bin/s.
# Invoked from scripts/test-helpers.sh; can also be run standalone.
#
# Manual smoke-test checklist (run these by hand after the suite passes):
#  1. Inside tmux session `dotfiles`, `s feature-x` -> new session
#     `dotfiles/feature-x` at the worktree path. Repeating `s feature-x`
#     -> switch-client to existing session, no second worktree created.
#  2. Outside tmux, `s` -> fzf picker -> pick `dotfiles` -> attach to
#     `dotfiles` session at ~/code/dotfiles.
#  3. Outside tmux, `s dotfiles feature-x` -> fresh `dotfiles/feature-x`
#     session with worktree at ~/code/dotfiles/.claude/worktrees/feature-x.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="$REPO/bin/s"

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

assert_contains() {
  local got="$1" needle="$2" desc="$3"
  if printf '%s' "$got" | grep -q -F -- "$needle"; then
    pass=$((pass+1))
    echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        needle: '$needle'")
    echo "  FAIL  $desc"
  fi
}

echo
echo "bin/s"
echo "─────"

if [ ! -x "$S" ]; then
  echo "  SKIP — $S not present yet"
else
  # too many args -> usage
  out=$(env -u TMUX "$S" a b c 2>&1); rc=$?
  assert_eq "$rc" "1" "too many args -> exit 1"
  assert_contains "$out" "Usage:" "too many args -> usage on stderr"
fi

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "test-s.sh passed: $pass"
echo "test-s.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
