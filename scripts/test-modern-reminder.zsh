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

# Functions under test (keep in sync with .zshrc)
typeset -gA _modern_reminder_pairs=(
  [tail]=tspin
  [grep]=rg
  [curl]=xh
)
typeset -gA _modern_reminder_hints=(
  [tail]="tspin is a modern alternative to tail. Try \`tspin -f app.log\`."
  [grep]="rg is a modern alternative to grep."
  [curl]="xh (HTTPie-compatible) is a modern alternative to curl."
)
typeset -gA _modern_reminder_seen
typeset -g _modern_reminder_pending=""

_modern_reminder_preexec() {
  [[ -z ${MODERN_REMINDER:-} ]] && return
  _modern_reminder_pending=""
  # Stub: real token scan added in Task 5. For now: first-token-only.
  local first="${${(z)1}[1]}"
  if [[ -n "${_modern_reminder_pairs[$first]:-}" ]]; then
    _modern_reminder_pending="$first"
  fi
}

_modern_reminder_precmd() {
  local cmd="$_modern_reminder_pending"
  _modern_reminder_pending=""
  [[ -z ${MODERN_REMINDER:-} ]] && return
  [[ -z $cmd ]] && return
  [[ -n "${_modern_reminder_seen[$cmd]:-}" ]] && return
  print -P "%F{yellow}%f ${_modern_reminder_hints[$cmd]}"
  _modern_reminder_seen[$cmd]=1
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
tmp=$(mktemp -t mr.XXXXXX)
_run_hooks "grep TODO src/" >"$tmp" 2>&1
out=$(<"$tmp"); rm -f "$tmp"
assert_not_contains "$out" "modern alternative" \
  "MODERN_REMINDER unset -> no reminder"

# Test 2: fires once per session
export MODERN_REMINDER=1
_modern_reminder_seen=()
tmp1=$(mktemp -t mr.XXXXXX); tmp2=$(mktemp -t mr.XXXXXX)
_run_hooks "grep TODO src/"   >"$tmp1" 2>&1
_run_hooks "grep TODO other/" >"$tmp2" 2>&1
out1=$(<"$tmp1"); out2=$(<"$tmp2")
rm -f "$tmp1" "$tmp2"
assert_contains "$out1" "rg is a modern alternative to grep" \
  "First grep call -> reminder fires"
assert_not_contains "$out2" "modern alternative" \
  "Second grep call in same shell -> silent"

echo
echo "Total: $((pass+fail))  pass: $pass  fail: $fail"
if (( fail > 0 )); then
  for msg in "${fail_msgs[@]}"; do echo; echo "$msg"; done
  exit 1
fi
exit 0
