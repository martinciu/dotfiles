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

# Forward: mocha → dracula
run_theme_set dracula
assert_link "$HOME/.config/themes/current.tmux"               "dracula.tmux"               "current.tmux → dracula.tmux"
assert_link "$HOME/.config/themes/delta-current.gitconfig"    "delta-dracula.gitconfig"    "delta-current.gitconfig → delta-dracula.gitconfig"
assert_link "$HOME/.config/ghostty/theme.ghostty"             "theme-dracula.ghostty"      "ghostty theme.ghostty → theme-dracula.ghostty"
assert_link "$HOME/.config/starship.toml"                     "starship-dracula.toml"      "starship.toml → starship-dracula.toml"
assert_link "$HOME/.config/glow/glamour.json"                 "glamour-dracula.json"       "glow glamour.json → glamour-dracula.json"
assert_link "$HOME/.config/gh-dash/config.yml"                "config-dracula.yml"         "gh-dash config.yml → config-dracula.yml"
assert_link "$HOME/.config/lnav/configs/installed/theme.json" "theme-dracula.json"         "lnav theme.json → theme-dracula.json"

# Forward: dracula → gruvbox
run_theme_set gruvbox
assert_link "$HOME/.config/themes/current.tmux"               "gruvbox.tmux"               "current.tmux → gruvbox.tmux"
assert_link "$HOME/.config/themes/delta-current.gitconfig"    "delta-gruvbox.gitconfig"    "delta-current.gitconfig → delta-gruvbox.gitconfig"
assert_link "$HOME/.config/ghostty/theme.ghostty"             "theme-gruvbox.ghostty"      "ghostty theme.ghostty → theme-gruvbox.ghostty"
assert_link "$HOME/.config/starship.toml"                     "starship-gruvbox.toml"      "starship.toml → starship-gruvbox.toml"
assert_link "$HOME/.config/glow/glamour.json"                 "glamour-gruvbox.json"       "glow glamour.json → glamour-gruvbox.json"
assert_link "$HOME/.config/gh-dash/config.yml"                "config-gruvbox.yml"         "gh-dash config.yml → config-gruvbox.yml"
assert_link "$HOME/.config/lnav/configs/installed/theme.json" "theme-gruvbox.json"         "lnav theme.json → theme-gruvbox.json"

# Forward: gruvbox → tokyo-night
run_theme_set tokyo-night
assert_link "$HOME/.config/themes/current.tmux"               "tokyo-night.tmux"               "current.tmux → tokyo-night.tmux"
assert_link "$HOME/.config/themes/delta-current.gitconfig"    "delta-tokyo-night.gitconfig"    "delta-current.gitconfig → delta-tokyo-night.gitconfig"
assert_link "$HOME/.config/ghostty/theme.ghostty"             "theme-tokyo-night.ghostty"      "ghostty theme.ghostty → theme-tokyo-night.ghostty"
assert_link "$HOME/.config/starship.toml"                     "starship-tokyo-night.toml"      "starship.toml → starship-tokyo-night.toml"
assert_link "$HOME/.config/glow/glamour.json"                 "glamour-tokyo-night.json"       "glow glamour.json → glamour-tokyo-night.json"
assert_link "$HOME/.config/gh-dash/config.yml"                "config-tokyo-night.yml"         "gh-dash config.yml → config-tokyo-night.yml"
assert_link "$HOME/.config/lnav/configs/installed/theme.json" "theme-tokyo-night.json"         "lnav theme.json → theme-tokyo-night.json"

# Reverse: tokyo-night → solarized
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
