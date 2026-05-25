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

echo "── history parser ──"
fixture="$(mktemp)"
cat >"$fixture" <<'EOF'
- cmd: theme-set frappe
  when: 1778000000
- cmd: theme-set catpuccin
  when: 1778000100
- cmd: ls
  when: 1778000200
- cmd: theme-set solarized
  when: 1778000300
- cmd: theme-set rose-pine-moon
  when: 1778000400
EOF
hist_out="$(FISH_HISTORY_FILE="$fixture" fishrun '__theme_font_history theme-set (__theme_set_names)')"
want_hist="$(printf '1778000000\tfrappe\n1778000300\tsolarized\n1778000400\trose-pine-moon')"
assert_eq "$hist_out" "$want_hist" "history parser: drops typos, keeps valid, sorted asc"
rm -f "$fixture"

echo "── report aggregation ──"
# Three selections; now is 1d after the last switch.
# frappe: 1778000000→1778086400 = 86400s (1d)
# solarized: 1778086400→1778108000 = 21600s (6h)
# rose-pine-moon: 1778108000→now(1778194400) = 86400s (1d), current
rows="$(printf '1778000000\tfrappe\n1778086400\tsolarized\n1778108000\trose-pine-moon')"
agg="$(printf '%s' "$rows" | THEME_FONT_STATS_NOW=1778194400 \
      fishrun '__theme_font_stats_report --raw THEME rose-pine-moon 0 (__theme_set_names)')"
# Expect rose-pine-moon and frappe tied at 86400 (rpm first by name? define: stable, ties broken by last-set desc → rpm before frappe), solarized last.
assert_contains "$agg" $'frappe\t86400\t1\t1778000000' "agg: frappe total 1d, sw 1"
assert_contains "$agg" $'solarized\t21600\t1\t1778086400' "agg: solarized total 6h"
assert_contains "$agg" $'rose-pine-moon\t86400\t1\t1778108000' "agg: rpm total 1d, current"
first_line="$(printf '%s' "$agg" | head -1 | cut -f1)"
assert_eq "$first_line" "rose-pine-moon" "agg: ties broken by most-recent last-set (rpm first)"

echo "── report rendering ──"
# Add a sub-minute taste of gruvbox between solarized and rpm.
rows2="$(printf '1778000000\tfrappe\n1778086400\tsolarized\n1778107970\tgruvbox\n1778108000\trose-pine-moon')"
# gruvbox active 1778107970→1778108000 = 30s (sub-minute → hidden by default).
out_default="$(printf '%s' "$rows2" | THEME_FONT_STATS_NOW=1778194400 \
  fishrun '__theme_font_stats_report THEME rose-pine-moon 0 (__theme_set_names)')"
assert_contains "$out_default" "← current" "render: current row marked"
assert_contains "$out_default" "rose-pine-moon" "render: current name present"
assert_not_contains "$out_default" "gruvbox  " "render: sub-minute gruvbox hidden by default"
assert_contains "$out_default" "short selections hidden" "render: hidden-count line shown"
assert_contains "$out_default" "— never" "render: never-used names listed"
assert_contains "$out_default" "tracked window" "render: footer present"
# Piped output must be plain (no ANSI escape introducer).
assert_not_contains "$out_default" $'\e[' "render: no ANSI escapes when piped"

out_all="$(printf '%s' "$rows2" | THEME_FONT_STATS_NOW=1778194400 \
  fishrun '__theme_font_stats_report THEME rose-pine-moon 1 (__theme_set_names)')"
assert_contains "$out_all" "gruvbox" "render --all: sub-minute gruvbox shown"

echo "── theme-set dispatcher ──"
tfix="$(mktemp)"
cat >"$tfix" <<'EOF'
- cmd: theme-set frappe
  when: 1778000000
- cmd: theme-set rose-pine-moon
  when: 1778108000
EOF
# --stats: no name arg → should print a report, not the usage error.
stats_out="$(FISH_HISTORY_FILE="$tfix" THEME_FONT_STATS_NOW=1778194400 \
  fishrun 'theme-set --stats')"
assert_contains "$stats_out" "frappe" "theme-set --stats prints report"
assert_not_contains "$stats_out" "Usage:" "theme-set --stats is not the usage error"
# --help still shows usage.
help_out="$(fishrun 'theme-set --help')"
assert_contains "$help_out" "Usage:" "theme-set --help shows usage"
# Invalid name still errors (stderr captured).
inv_out="$(fishrun 'theme-set bogus' 2>&1)"
assert_contains "$inv_out" "Usage:" "theme-set <invalid> still errors"
rm -f "$tfix"

echo "── font-set dispatcher ──"
ffix="$(mktemp)"
cat >"$ffix" <<'EOF'
- cmd: font-set jetbrains
  when: 1778000000
- cmd: font-set monaspace Bold 14
  when: 1778108000
EOF
fstats="$(FISH_HISTORY_FILE="$ffix" THEME_FONT_STATS_NOW=1778194400 \
  fishrun 'font-set --stats')"
assert_contains "$fstats" "monaspace" "font-set --stats prints report"
assert_not_contains "$fstats" "Usage:" "font-set --stats is not the usage error"
# weight/size-only re-run merges into family: jetbrains appears once, monaspace once.
mono_rows="$(printf '%s' "$fstats" | grep -c 'monaspace')"
assert_eq "$mono_rows" "1" "font-set --stats: monaspace merged to one row"
fhelp="$(fishrun 'font-set --help' 2>&1)"
assert_contains "$fhelp" "Usage:" "font-set --help shows usage"
rm -f "$ffix"

# ── (later tasks append sections above this summary block) ──

echo
if [ "$fail" -gt 0 ]; then
  echo "❌ $fail failed, $pass passed"
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
echo "✅ all $pass checks passed"
