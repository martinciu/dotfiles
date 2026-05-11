#!/opt/homebrew/bin/bash
# Smoke test for theme-set. Flips theme both directions and asserts that
# key symlinks point to the expected variant. Does NOT validate live tmux
# redraws or GUI reloads — those are eyeball-level concerns.
set -uo pipefail

pass=0
fail=0
fail_msgs=()

assert_link() {
    local link="$1" want="$2" desc="$3"
    local got
    got="$(readlink "$link" 2>/dev/null || echo '<missing>')"
    if [ "$got" = "$want" ]; then
        pass=$((pass+1))
        echo "  PASS  $desc"
    else
        fail=$((fail+1))
        fail_msgs+=("FAIL  $desc"$'\n'"        link: $link"$'\n'"        got:  $got"$'\n'"        want: $want")
        echo "  FAIL  $desc"
    fi
}

REPO="${REPO:-$PROJECTS_HOME/dotfiles}"
THEME_SET_FN="$REPO/.config/fish/functions/theme-set.fish"

run_theme_set() {
    # Source the function from the repo so the test works regardless of
    # whether ~/.config/fish/functions/theme-set.fish has been wired yet
    # (e.g. on a freshly-checked-out branch before re-running bootstrap).
    fish -c "source $THEME_SET_FN; theme-set $1" >/dev/null
}

echo "theme-set smoke test"
echo "───────────────────"

# Remember the starting theme so we can restore at the end.
start_theme="$(readlink "$HOME/.config/themes/current.tmux" 2>/dev/null | sed 's/\.tmux$//')"
: "${start_theme:=solarized}"

# Forward: solarized → mocha
run_theme_set mocha
assert_link "$HOME/.config/themes/current.tmux"               "mocha.tmux"               "current.tmux → mocha.tmux"
assert_link "$HOME/.config/themes/delta-current.gitconfig"    "delta-mocha.gitconfig"    "delta-current.gitconfig → delta-mocha.gitconfig"
assert_link "$HOME/.config/ghostty/theme.ghostty"             "theme-mocha.ghostty"      "ghostty theme.ghostty → theme-mocha.ghostty"
assert_link "$HOME/.config/starship.toml"                     "starship-mocha.toml"      "starship.toml → starship-mocha.toml"
assert_link "$HOME/.config/glow/glamour.json"                 "glamour-mocha.json"       "glow glamour.json → glamour-mocha.json"
assert_link "$HOME/.config/gh-dash/config.yml"                "config-mocha.yml"         "gh-dash config.yml → config-mocha.yml"
assert_link "$HOME/.config/lnav/configs/installed/theme.json" "theme-mocha.json"         "lnav theme.json → theme-mocha.json"

# Reverse: mocha → solarized
run_theme_set solarized
assert_link "$HOME/.config/themes/current.tmux"               "solarized.tmux"             "current.tmux → solarized.tmux (reverse)"
assert_link "$HOME/.config/ghostty/theme.ghostty"             "theme-solarized.ghostty"    "ghostty theme.ghostty → theme-solarized.ghostty (reverse)"
assert_link "$HOME/.config/starship.toml"                     "starship-solarized.toml"    "starship.toml → starship-solarized.toml (reverse)"

# Restore starting state.
run_theme_set "$start_theme"

# Summary
echo
echo "───────────────────"
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    echo
    printf '%s\n' "${fail_msgs[@]}"
    exit 1
fi
