#!/opt/homebrew/bin/bash
# Smoke test for theme-set/font-set --stats + bare readout. Drives the pure
# fish helpers directly with a fixture history and a fixed "now" so durations
# are deterministic. Never touches live symlinks or the apply path.
set -uo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
FISH_DIR="$DOTFILES/.config/fish"

if ! command -v fish >/dev/null 2>&1; then
  echo "⏭️  fish not installed — skipping"
  exit 0
fi

pass=0
fail=0
fail_msgs=()

# Run a fish snippet with our functions autoloaded from the repo (not ~/.config).
fishrun() {
  fish -c "set -p fish_function_path '$FISH_DIR/functions'; $1"
}

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  $got"$'\n'"        want: $want")
    echo "  FAIL  $desc"
  fi
}

assert_contains() {
  local hay="$1" needle="$2" desc="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        wanted substring: $needle"$'\n'"        in: $hay")
    echo "  FAIL  $desc"
  fi
}

assert_not_contains() {
  local hay="$1" needle="$2" desc="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        unwanted substring present: $needle"$'\n'"        in: $hay")
    echo "  FAIL  $desc"
  else
    pass=$((pass+1)); echo "  PASS  $desc"
  fi
}

echo "── name lists ──"
theme_count="$(fishrun '__theme_set_names | count')"
assert_eq "$theme_count" "10" "__theme_set_names emits 10 themes"
assert_contains "$(fishrun '__theme_set_names')" "rose-pine-moon" "theme list includes rose-pine-moon"
font_count="$(fishrun '__font_set_names | count')"
assert_eq "$font_count" "17" "__font_set_names emits 17 fonts"
assert_contains "$(fishrun '__font_set_names')" "jetbrains" "font list includes jetbrains"

echo "── duration formatters ──"
assert_eq "$(fishrun '__theme_font_dur 293040')" "3d 9h 24m" "dur multi-day drops seconds"
assert_eq "$(fishrun '__theme_font_dur 3900')"   "1h 5m"     "dur hours"
assert_eq "$(fishrun '__theme_font_dur 72')"     "1m 12s"    "dur minutes+seconds"
assert_eq "$(fishrun '__theme_font_dur 42')"     "42s"       "dur seconds only"
assert_eq "$(fishrun '__theme_font_ago 259200')" "3d ago"    "ago top unit days"
assert_eq "$(fishrun '__theme_font_ago 18000')"  "5h ago"    "ago top unit hours"
assert_eq "$(fishrun '__theme_font_ago 30')"     "just now"  "ago under a minute"

# ── (later tasks append sections above this summary block) ──

echo
if [ "$fail" -gt 0 ]; then
  echo "❌ $fail failed, $pass passed"
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
echo "✅ all $pass checks passed"
