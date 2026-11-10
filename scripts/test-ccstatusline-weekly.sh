#!/opt/homebrew/bin/bash
# Smoke tests for .config/ccstatusline/bin/ccpulse-weekly.
#
# Strategy: PATH-shim ccpulse with a stub that emits canned JSON (or fails),
# pin the clock with CCPULSE_WEEKLY_NOW, and assert the chip body.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO/.config/ccstatusline/bin/ccpulse-weekly"

# quota_updated_at in every fixture below: 2026-11-10T20:00:00Z.
UPDATED=1794340800
GLYPH=$'\xef\x89\x92'   # U+F252 nf-fa-hourglass_half

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

setup_sandbox() {
  TEST_BIN=$(mktemp -d)
}

teardown_sandbox() {
  rm -rf "$TEST_BIN"
}

# stub_json <json>: ccpulse prints <json> and exits 0.
stub_json() {
  printf '#!/opt/homebrew/bin/bash\ncat <<'"'"'JSON'"'"'\n%s\nJSON\n' "$1" > "$TEST_BIN/ccpulse"
  chmod +x "$TEST_BIN/ccpulse"
}

# run_at <seconds after UPDATED>
run_at() {
  CCPULSE_WEEKLY_NOW=$((UPDATED + $1)) PATH="$TEST_BIN:$PATH" "$HELPER" 2>/dev/null
}

FIXTURE='{"percent_7d":25,"has_7d":true,"quota_updated_at":"2026-11-10T20:00:00.174541Z","quota_source":"cache_fresh"}'

echo "── ccpulse-weekly ──"

setup_sandbox
stub_json "$FIXTURE"
assert_eq "$(run_at 120)"    "25%"                 "fresh (2 min): bare percentage"
assert_eq "$(run_at 3600)"   "25%"                 "exactly 1h: still bare (marker only past the threshold)"
assert_eq "$(run_at 3601)"   "25% $GLYPH 1h"       "1h + 1s: hourglass + 1h"
assert_eq "$(run_at 10800)"  "25% $GLYPH 3h"       "3h: hourglass + 3h"
assert_eq "$(run_at 86399)"  "25% $GLYPH 23h"      "23h59m: still counted in hours"
assert_eq "$(run_at 180000)" "25% $GLYPH 2d"       "50h: switches to days"
assert_eq "$(CCPULSE_WEEKLY_STALE_AFTER=600 run_at 900)" "25% $GLYPH 0h" \
  "threshold override: 15 min old, 10 min threshold"
teardown_sandbox

setup_sandbox
stub_json '{"percent_7d":25,"has_7d":true,"quota_updated_at":"2026-11-10T20:00:00Z"}'
assert_eq "$(run_at 10800)" "25% $GLYPH 3h"        "timestamp without fractional seconds parses"
teardown_sandbox

setup_sandbox
stub_json '{"percent_7d":25,"has_7d":true,"quota_updated_at":null}'
assert_eq "$(run_at 10800)" "25%"                  "no quota_updated_at: percentage without marker"
teardown_sandbox

setup_sandbox
stub_json '{"percent":0,"has_7d":false}'
assert_eq "$(run_at 0)" "?"                        "no percent_7d: placeholder"
teardown_sandbox

setup_sandbox
stub_json 'not json'
assert_eq "$(run_at 0)" "?"                        "malformed JSON: placeholder"
teardown_sandbox

setup_sandbox
printf '#!/opt/homebrew/bin/bash\nexit 1\n' > "$TEST_BIN/ccpulse"
chmod +x "$TEST_BIN/ccpulse"
assert_eq "$(run_at 0)" "?"                        "ccpulse exits non-zero: placeholder"
CCPULSE_WEEKLY_NOW=0 PATH="$TEST_BIN:$PATH" "$HELPER" >/dev/null 2>&1
assert_eq "$?" "0"                                 "ccpulse exits non-zero: helper still exits 0"
teardown_sandbox

echo
echo "─────────────────"
echo "  Summary: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo
  for msg in "${fail_msgs[@]}"; do echo "$msg"; done
  exit 1
fi
exit 0
