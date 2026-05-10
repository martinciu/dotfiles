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

# Source the helper for direct function testing. The script normally
# reaches `exit 0` immediately when ccpulse is missing — we set a guard
# env var so the script defines functions and returns without rendering.
TMUX_CLAUDE_USAGE_NO_RUN=1 source "$HELPER"

assert_eq "$(format_reset 0)"     "now"     "format_reset(0)"
assert_eq "$(format_reset 1)"     "1m"      "format_reset(1)"
assert_eq "$(format_reset 37)"    "37m"     "format_reset(37)"
assert_eq "$(format_reset 59)"    "59m"     "format_reset(59)"
assert_eq "$(format_reset 60)"    "1h"      "format_reset(60) — minutes==0 case"
assert_eq "$(format_reset 65)"    "1h5m"    "format_reset(65)"
assert_eq "$(format_reset 217)"   "3h37m"   "format_reset(217)"
assert_eq "$(format_reset 1439)"  "23h59m"  "format_reset(1439) — last sub-day value"
assert_eq "$(format_reset 1440)"  "1d 0h"   "format_reset(1440) — exactly 24h"
assert_eq "$(format_reset 5000)"  "3d 11h"  "format_reset(5000)"
unset -f format_reset
unset TMUX_CLAUDE_USAGE_NO_RUN

# Case: resets_at already past -> mins_7d clamps to 0; helper still runs
# (positive output asserted in Task 6's "now" rendering test).
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":6,"minutes_to_reset":237,"quota":{"five_hour":{"utilization":6,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2020-01-01T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_eq "$?" "0" "resets_at in past does not abort the helper"
teardown_sandbox

# Case: happy path, both pcts low. 5h shows pct + reset; 7d shows
# pct only (compact). Verify each visible substring.
setup_sandbox
# Use a future-far seven_day reset (large minutes_until value) so that
# format_reset returns a multi-day string we can spot-check.
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)

# Robot chip: cyan on bar_bg
assert_contains "$got" "#[fg=#2aa198,bg=#073642]" "robot chip uses cyan on bar bg"
# Robot body: base3-on-cyan
assert_contains "$got" "#[fg=#fdf6e3,bg=#2aa198,bold]" "robot chip body uses base3-on-cyan bold"
# Robot has robot glyph (U+1F916, the standard 🤖 emoji — chosen over the
# Nerd Font U+F544 in commit 254840b for portability).
assert_contains "$got" $'\xf0\x9f\xa4\x96'              "robot glyph (U+1F916)"
# Violet chip cap: violet on cyan (robot bg), not bar bg. The helper emits
# attribute pairs in bg,fg order — match the actual byte sequence.
assert_contains "$got" "#[bg=#6c71c4,fg=#2aa198]" "7d chip uses violet on cyan"
assert_contains "$got" "#[fg=#fdf6e3,bg=#6c71c4,bold]" "7d chip body uses base3-on-violet bold"
assert_contains "$got" "8%"                            "5h pct visible"
assert_contains "$got" "3h37m"                         "5h reset visible"
assert_contains "$got" "#[bg=#b58900,fg=#6c71c4]"      "5h chip cap fuses yellow on violet"
assert_contains "$got" "#[fg=#073642,bg=#b58900,bold]" "5h chip body uses base02-on-yellow bold"
assert_contains "$got" "21%"                            "7d pct visible"
assert_not_contains "$got" "21% • "                     "7d compact: no • reset suffix when low"
# Bolt for 5h, calendar (oct) for 7d — UTF-8 byte sequences as in helper.
assert_contains "$got" $'\xef\x89\x92'                  "5h hourglass glyph (U+F252)"
assert_contains "$got" $'\xef\x91\x95'                  "7d calendar glyph (U+F455)"
# Powerline rounded caps: left U+E0B6, right U+E0B4.
assert_contains "$got" $'\xee\x82\xb6'                  "left rounded cap"
assert_contains "$got" $'\xee\x82\xb4'                  "right rounded cap (closes 5h)"
teardown_sandbox

# Carryover: past resets_at + low 7d pct -> compact body still renders pct.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":6,"minutes_to_reset":237,"quota":{"five_hour":{"utilization":6,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2020-01-01T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "21%" "past resets_at: helper renders normally (compact)"
teardown_sandbox

# Case: 7d high (94%) -> expanded body with • <reset>.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":94,"resets_at":"2099-12-31T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "94%"        "7d high: pct visible"
assert_contains "$got" "94% • "     "7d high: auto-expanded with • separator"
teardown_sandbox

# Case: 7d at exactly threshold (80) -> expanded (>= is the rule).
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":80,"resets_at":"2099-12-31T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "80% • " "7d at boundary 80: auto-expanded (>= rule)"
teardown_sandbox

# Case: 7d just below threshold (79) -> compact (no • separator after pct).
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":79,"resets_at":"2099-12-31T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains      "$got" "79%"      "7d below boundary 79: pct visible"
assert_not_contains  "$got" "79% • "   "7d below boundary 79: compact (no • separator)"
teardown_sandbox

# Case: resets_at in past + 7d high pct -> mins_7d=0 -> "now" in expanded body.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":95,"resets_at":"2020-01-01T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "95% • now" "past resets_at + high pct: clamps to 'now'"
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
