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

# format_overreach_suffix — direct unit tests.
# The helper returns:
#   - empty string when will is anything but "true"
#   - " <fire> → N%"  when will=="true" and pct is non-empty
#   - " <fire>"        when will=="true" and pct is empty (graceful degrade
#                       on null projected_pct_at_reset).
fire_glyph=$'\xef\x81\xad'
arrow_glyph=$'\xe2\x86\x92'

# Existing show-path calls now pass an explicit confidence (3rd arg). Required:
# the harness runs under `set -u`, so once the function references $3 a missing
# arg would abort with "unbound variable".
assert_eq "$(format_overreach_suffix true 120 ok)"  " ${fire_glyph} ${arrow_glyph} 120%" "format_overreach_suffix(true, 120, ok)"
assert_eq "$(format_overreach_suffix true 252 ok)"  " ${fire_glyph} ${arrow_glyph} 252%" "format_overreach_suffix(true, 252, ok)"
assert_eq "$(format_overreach_suffix true '' ok)"   " ${fire_glyph}"                     "format_overreach_suffix(true, '', ok) — null projected_pct"
assert_eq "$(format_overreach_suffix false 120 ok)" ""                                    "format_overreach_suffix(false, 120, ok)"
assert_eq "$(format_overreach_suffix '' 120 ok)"    ""                                    "format_overreach_suffix('', 120, ok)"
assert_eq "$(format_overreach_suffix false '' ok)"  ""                                    "format_overreach_suffix(false, '', ok)"

# Confidence gate (issue #252): explicit "low" suppresses; empty/"ok" show.
assert_eq "$(format_overreach_suffix true 187 low)" ""                                    "gate: low confidence suppresses suffix"
assert_eq "$(format_overreach_suffix true 187 ok)"  " ${fire_glyph} ${arrow_glyph} 187%" "gate: ok confidence shows suffix"
assert_eq "$(format_overreach_suffix true 187 '')"  " ${fire_glyph} ${arrow_glyph} 187%" "gate: empty confidence defaults to show (old ccpulse)"
assert_eq "$(format_overreach_suffix true '' low)"  ""                                    "gate: low confidence suppresses even with null pct"
unset -f format_overreach_suffix
unset fire_glyph arrow_glyph

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

# Violet chip now opens directly against bar_bg with a left rounded cap.
assert_contains "$got" "#[fg=#6c71c4,bg=#073642]"     "violet chip cap is violet on bar bg"
# Robot still rendered, now inside the violet body alongside the calendar
# (U+1F916 emoji, chosen over Nerd Font U+F544 in commit 254840b for portability).
assert_contains "$got" $'\xf0\x9f\xa4\x96'            "robot glyph (U+1F916) present"
# Cyan chip should no longer appear anywhere in the output.
assert_not_contains "$got" "bg=#2aa198"               "no standalone cyan chip emitted"
assert_not_contains "$got" "fg=#2aa198"               "no cyan foreground anywhere"
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

# ─── Overreach prediction: 5h chip ───────────
# Case: 5h will_overreach=true with projected_pct_at_reset=120.
# Expect body to contain the overreach decoration before the bullet+reset:
#   ⏳ 8% 🔥 → 120% • 3h37m
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":true,"projected_pct_at_reset":120},"seven_day":{"will_overreach":false,"projected_pct_at_reset":34}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" $'\xef\x81\xad'              "5h overreach: fire glyph (U+F06D) present"
assert_contains "$got" "8% "$'\xef\x81\xad'" "$'\xe2\x86\x92'" 120% • " "5h overreach: '8% 🔥 → 120% • ' substring"
teardown_sandbox

# Case: 5h will_overreach=false — no fire glyph anywhere in 5h body.
# (We can't easily isolate "5h body" from output, so we assert no fire
# glyph at all, given 7d is also false.)
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34},"seven_day":{"will_overreach":false,"projected_pct_at_reset":34}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_not_contains "$got" $'\xef\x81\xad' "5h not overreaching, 7d not overreaching: no fire glyph anywhere"
teardown_sandbox

# ─── Overreach prediction: 7d chip ───────────
# Case: 7d compact (pct=21 < 80) AND will_overreach=true.
# Expect: chip expands to "🤖 📅 21% 🔥 → 252%" with NO • <reset> suffix
# (per spec §1: at pct<80 the 7d window's reset is days away and not
# rendered; the overreach decoration is the entire expansion).
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34},"seven_day":{"will_overreach":true,"projected_pct_at_reset":252}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains     "$got" "21% "$'\xef\x81\xad'" "$'\xe2\x86\x92'" 252%" "7d compact + overreach: '21% 🔥 → 252%'"
assert_not_contains "$got" "252% • "                                       "7d compact + overreach: no • reset suffix"
teardown_sandbox

# Case: 7d expanded (pct=80) AND will_overreach=true. Expect both the
# overreach decoration AND the • <reset> suffix.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":80,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34},"seven_day":{"will_overreach":true,"projected_pct_at_reset":120}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "80% "$'\xef\x81\xad'" "$'\xe2\x86\x92'" 120% • " "7d expanded + overreach: '80% 🔥 → 120% • '"
teardown_sandbox

# Case: 7d compact (pct=11 < 80), will_overreach=false. Expect compact
# body unchanged (no fire glyph, no • reset suffix).
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":11,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34},"seven_day":{"will_overreach":false,"projected_pct_at_reset":15}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains     "$got" "11%"                "7d compact, no overreach: pct visible"
assert_not_contains "$got" $'\xef\x81\xad'      "7d compact, no overreach: no fire glyph"
assert_not_contains "$got" "11% • "             "7d compact, no overreach: no • reset suffix"
teardown_sandbox

# ─── Graceful degradation: missing/partial projection field ──
# Case: ccpulse JSON has all four core fields but no `projection` key
# at all (older ccpulse). Expect both chips render exactly as today,
# no fire glyph anywhere, both chips visible.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains     "$got" "8%"            "missing projection: 5h pct visible (chip not hidden)"
assert_contains     "$got" "21%"           "missing projection: 7d pct visible (chip not hidden)"
assert_contains     "$got" "3h37m"         "missing projection: 5h reset visible (chip body intact)"
assert_not_contains "$got" $'\xef\x81\xad' "missing projection: no fire glyph emitted"
teardown_sandbox

# Case: will_overreach=true but projected_pct_at_reset=null on 7d. Expect
# the fire glyph alone (no '→ N%' suffix), still on the 7d chip.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34},"seven_day":{"will_overreach":true,"projected_pct_at_reset":null}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains     "$got" "21% "$'\xef\x81\xad' "null projected_pct + overreach: '21% 🔥' present"
assert_not_contains "$got" $'\xe2\x86\x92'        "null projected_pct + overreach: no arrow glyph"
teardown_sandbox

# ─── Confidence gating (issue #252) ──────────
# Case: 7d overreach but confidence "low" (53-min-in 187% scenario). Expect the
# decoration fully suppressed: no fire glyph, and the chip stays COMPACT (pct<80
# so no auto-expand from a now-empty suffix). pct still renders.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34,"confidence":"ok"},"seven_day":{"will_overreach":true,"projected_pct_at_reset":187,"confidence":"low"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains     "$got" "21%"            "7d low-confidence overreach: pct still visible"
assert_not_contains "$got" $'\xef\x81\xad'  "7d low-confidence overreach: fire glyph suppressed"
assert_not_contains "$got" "21% • "         "7d low-confidence overreach: no auto-expand (stays compact)"
teardown_sandbox

# Case: same 7d overreach but confidence "ok" — regression guard that trusted
# projections still render the decoration.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34,"confidence":"ok"},"seven_day":{"will_overreach":true,"projected_pct_at_reset":187,"confidence":"ok"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "21% "$'\xef\x81\xad'" "$'\xe2\x86\x92'" 187%" "7d ok-confidence overreach: '21% 🔥 → 187%' shown"
teardown_sandbox

# Case: 5h overreach with confidence "low" (7d not overreaching) — 5h gate works,
# no fire glyph anywhere.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":true,"projected_pct_at_reset":120,"confidence":"low"},"seven_day":{"will_overreach":false,"projected_pct_at_reset":34,"confidence":"ok"}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains     "$got" "8%"             "5h low-confidence overreach: pct still visible"
assert_not_contains "$got" $'\xef\x81\xad'  "5h low-confidence overreach: fire glyph suppressed"
teardown_sandbox

# Case: 7d overreach with NO confidence key at all (older ccpulse). Default-to-ok
# means the decoration still shows — explicit graceful-degradation coverage.
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":21,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":false,"projected_pct_at_reset":34},"seven_day":{"will_overreach":true,"projected_pct_at_reset":187}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
assert_contains "$got" "21% "$'\xef\x81\xad'" "$'\xe2\x86\x92'" 187%" "missing confidence key: decoration still shown (default-to-ok)"
teardown_sandbox

# Case: both chips overreach simultaneously. Assert two distinct
# fire-glyph occurrences and that the body bodies fit (rough printable-
# length check, stripping tmux #[...] segments).
setup_sandbox
cat > "$TEST_BIN/ccpulse" <<'STUB'
#!/opt/homebrew/bin/bash
cat <<'JSON'
{"percent":8,"minutes_to_reset":217,"quota":{"five_hour":{"utilization":8,"resets_at":"2026-05-09T21:10:00Z"},"seven_day":{"utilization":80,"resets_at":"2099-12-31T00:00:00Z"}},"projection":{"five_hour":{"will_overreach":true,"projected_pct_at_reset":120},"seven_day":{"will_overreach":true,"projected_pct_at_reset":120}}}
JSON
STUB
chmod +x "$TEST_BIN/ccpulse"
got=$(run_helper)
# Two distinct occurrences of the fire byte sequence (one per chip).
fire_count=$(printf '%s' "$got" | grep -o $'\xef\x81\xad' | wc -l | tr -d ' ')
assert_eq "$fire_count" "2" "both chips overreach: fire glyph appears twice"
# Printable length (strip tmux #[...] format segments) under
# status-left-length budget (120). Sanity check, not a tight bound.
stripped=$(printf '%s' "$got" | sed -E 's/#\[[^]]*\]//g')
printable_len=${#stripped}
if [ "$printable_len" -lt 120 ]; then
  pass=$((pass+1)); echo "  PASS  both chips overreach: printable length $printable_len < 120"
else
  fail=$((fail+1)); fail_msgs+=("FAIL  both chips overreach: printable length $printable_len >= 120 (status-left-length budget)")
  echo "  FAIL  both chips overreach: printable length $printable_len >= 120"
fi
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
