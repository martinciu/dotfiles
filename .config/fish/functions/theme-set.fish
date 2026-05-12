function theme-set --description 'Switch colour scheme between solarized, mocha, dracula, gruvbox, and tokyo-night'
    set -l name $argv[1]
    switch $name
        case solarized mocha dracula gruvbox tokyo-night
            # OK
        case '*'
            echo "Usage: theme-set <solarized|mocha|dracula|gruvbox|tokyo-night>" >&2
            return 1
    end

    set -l bat_theme
    set -l vivid_theme
    switch $name
        case mocha
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "catppuccin-mocha"
        case dracula
            set bat_theme "Dracula"
            set vivid_theme "dracula"
        case gruvbox
            set bat_theme "gruvbox-dark"
            set vivid_theme "gruvbox-dark"
        case tokyo-night
            # bat 0.26 has no tokyonight syntax theme; fall back to
            # Catppuccin Mocha (closest pastel-on-dark in bat's catalogue).
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "tokyonight-storm"
        case '*'
            set bat_theme "Solarized (dark)"
            set vivid_theme "solarized-dark"
    end

    # Flip symlinks. -sfn replaces the link atomically.
    ln -sfn $name.tmux              ~/.config/themes/current.tmux
    ln -sfn delta-$name.gitconfig   ~/.config/themes/delta-current.gitconfig
    ln -sfn theme-$name.ghostty     ~/.config/ghostty/theme.ghostty
    ln -sfn starship-$name.toml     ~/.config/starship.toml
    ln -sfn glamour-$name.json      ~/.config/glow/glamour.json
    ln -sfn theme-$name.json        ~/.config/lnav/configs/installed/theme.json

    # gh-dash live config is a generated real file, not a symlink.
    # base.yml has no `theme:` key; theme-colors-$name.yml has only `theme:` —
    # plain concatenation produces valid YAML, no merge engine needed.
    cat \
        ~/.config/gh-dash/config-base.yml \
        ~/.config/gh-dash/theme-colors-$name.yml \
        > ~/.config/gh-dash/config.yml

    # Persisted env vars; survive shell restarts. Open shells need new
    # session to pick up the values. BAT_THEME is read by bat at startup;
    # VIVID_THEME is read by .config/fish/conf.d/10-colors.fish at fish
    # startup to regenerate LS_COLORS via `vivid generate`. fzf colors are
    # palette-symbolic (ANSI 0–15 refs) and auto-adapt via Ghostty's
    # 16-color palette — no env var needed.
    set -Ux BAT_THEME $bat_theme
    set -Ux VIVID_THEME $vivid_theme

    # tmux: re-source config + force status redraw (silent if no server).
    tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null
    tmux refresh-client -S                    2>/dev/null

    echo "theme → $name"
    echo "  live:    tmux + helpers, starship (next prompt), glow, delta"
    echo "  restart: bat + ls colors (new shells for \$BAT_THEME / \$VIVID_THEME), nvim, gh-dash, lnav"

    # Fire the ghostty config reload (cmd+ctrl+shift+r via System Events when
    # Ghostty is frontmost). Discard the helper's info line — the reload still
    # happens as a side effect; the printed "how to" was just noise.
    __ghostty_reload >/dev/null
end
