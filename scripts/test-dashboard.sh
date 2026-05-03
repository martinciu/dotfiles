#!/usr/bin/env bash
# Smoke + integration tests for bin/dashboard.
# Invoked from scripts/test-helpers.sh; can also be run standalone.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DASH="$REPO/bin/dashboard"

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
echo "bin/dashboard"
echo "─────────────"

if [ ! -x "$DASH" ]; then
  echo "  SKIP — $DASH not present yet"
else
  # ── arg parsing: 0 args -> usage on stderr, exit 1 ──
  out=$("$DASH" 2>&1); rc=$?
  assert_eq "$rc" "1" "0 args -> exit 1"
  assert_contains "$out" "Usage:" "0 args -> usage on stderr"

  # ── arg parsing: --cols requires a numeric value ──
  out=$("$DASH" '*-test' --cols 2>&1); rc=$?
  assert_eq "$rc" "1" "--cols without value -> exit 1"
  assert_contains "$out" "--cols requires" "--cols without value -> error message"

  out=$("$DASH" '*-test' --cols abc 2>&1); rc=$?
  assert_eq "$rc" "1" "--cols non-numeric -> exit 1"
  assert_contains "$out" "--cols requires" "--cols non-numeric -> error message"

  # ── derived_name: pattern -> session-name suffix ──
  out=$(DASHBOARD_TEST_DERIVED='*-agent' "$DASH" --print-derived 2>&1)
  assert_eq "$out" "agent" "'*-agent' -> derived 'agent'"

  out=$(DASHBOARD_TEST_DERIVED='claude-*-prod' "$DASH" --print-derived 2>&1)
  assert_eq "$out" "claudeprod" "'claude-*-prod' -> derived 'claudeprod'"

  out=$(DASHBOARD_TEST_DERIVED='build-*' "$DASH" --print-derived 2>&1)
  assert_eq "$out" "build" "'build-*' -> derived 'build'"

  # ── derived_name: empty result -> error ──
  out=$(DASHBOARD_TEST_DERIVED='***' "$DASH" --print-derived 2>&1); rc=$?
  assert_eq "$rc" "1" "all-special pattern -> exit 1"
  assert_contains "$out" "empty derived name" "all-special pattern -> error message"
fi

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "test-dashboard.sh passed: $pass"
echo "test-dashboard.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
