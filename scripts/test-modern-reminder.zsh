#!/usr/bin/env zsh
# Tests for the modern-reminder zsh hooks.
# Run: zsh scripts/test-modern-reminder.zsh
set -u

pass=0; fail=0; fail_msgs=()

assert_contains() {
  local got="$1" needle="$2" desc="$3"
  if printf '%s' "$got" | grep -q -F -- "$needle"; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:    '$got'"$'\n'"        needle: '$needle'")
    echo "  FAIL  $desc"
  fi
}

assert_not_contains() {
  local got="$1" needle="$2" desc="$3"
  if ! printf '%s' "$got" | grep -q -F -- "$needle"; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got contained: '$needle'")
    echo "  FAIL  $desc"
  fi
}

# helper: clear state, run preexec then precmd, return captured stdout
_run_hooks() {
  local cmdline="$1"
  _modern_reminder_pending=""
  _modern_reminder_preexec "$cmdline"
  _modern_reminder_precmd
}

echo
echo "modern-reminder"

# Test 1: disabled when env var unset
unset MODERN_REMINDER
out=$( _run_hooks "grep TODO src/" 2>&1 )
assert_not_contains "$out" "modern alternative" \
  "MODERN_REMINDER unset -> no reminder"

echo
echo "Total: $((pass+fail))  pass: $pass  fail: $fail"
if (( fail > 0 )); then
  for msg in "${fail_msgs[@]}"; do echo; echo "$msg"; done
  exit 1
fi
exit 0
