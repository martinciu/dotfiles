#!/opt/homebrew/bin/bash
# Smoke tests for tmux-claude-usage.
#
# Strategy: PATH-shim ccpulse with a stub that emits canned JSON
# (or fails) and assert that the helper renders the chip pair we
# expect (or hides cleanly).
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO/.config/tmux/bin/tmux-claude-usage"

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

assert_not_contains() {
  local got="$1" needle="$2" desc="$3"
  if printf '%s' "$got" | grep -q -F -- "$needle"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got: '$got'"$'\n'"        unwanted: '$needle'")
    echo "  FAIL  $desc"
  else
    pass=$((pass+1))
    echo "  PASS  $desc"
  fi
}

# Build a sandbox: a bin/ holding a ccpulse stub. Caller writes the
# desired stub body and exit code into $TEST_BIN/ccpulse before
# running the helper with PATH=$TEST_BIN:$PATH.
setup_sandbox() {
  TEST_BIN=$(mktemp -d)
}

teardown_sandbox() {
  [ -n "${TEST_BIN:-}" ] && rm -rf "$TEST_BIN"
}

# Run the helper with PATH-shimmed ccpulse. Emits stdout.
run_helper() {
  PATH="$TEST_BIN:$PATH" bash "$HELPER" 2>/dev/null
}

# ─── tmux-claude-usage: harness sanity ──────
echo
echo "tmux-claude-usage"
echo "─────────────────"

# Sanity: helper exists at expected path
if [ -e "$HELPER" ]; then
  pass=$((pass+1)); echo "  PASS  helper exists at $HELPER"
else
  fail=$((fail+1)); fail_msgs+=("FAIL  helper missing at $HELPER")
  echo "  FAIL  helper missing at $HELPER"
fi

# Case: ccpulse missing on PATH (TEST_BIN intentionally has nothing in it,
# and PATH contains only TEST_BIN — so command -v ccpulse fails).
setup_sandbox
got=$(PATH="$TEST_BIN" bash "$HELPER" 2>/dev/null)
assert_eq "$got" "" "hides when ccpulse is missing on PATH"
teardown_sandbox

# Case: ccpulse on PATH but exits non-zero
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
exit 1
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_eq "$got" "" "hides when ccpulse exits non-zero"
teardown_sandbox

# Case: ccpulse JSON missing seven_day quota -> hide both chips
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":6,"minutes_to_reset":237,"quota":{"five_hour":{"utilization":6,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":null}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_eq "$got" "" "hides when seven_day quota is null"
teardown_sandbox

# Case: ccpulse JSON missing top-level percent -> hide
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"minutes_to_reset":237,"quota":{"seven_day":{"utilization":21,"resets_at":"2026-05-10T09:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_eq "$got" "" "hides when top-level percent is missing"
teardown_sandbox

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "  Summary: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo
  for msg in "${fail_msgs[@]}"; do echo "$msg"; done
  exit 1
fi
exit 0
