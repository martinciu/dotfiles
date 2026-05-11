function theme-set --description 'Switch colour scheme between solarized, mocha, dracula, and gruvbox'
    set -l name $argv[1]
    switch $name
        case solarized mocha dracula gruvbox
            # OK
        case '*'
            echo "Usage: theme-set <solarized|mocha|dracula|gruvbox>" >&2
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
    ln -sfn config-$name.yml        ~/.config/gh-dash/config.yml
    ln -sfn theme-$name.json        ~/.config/lnav/configs/installed/theme.json

    # Persisted env vars; survive shell restarts. Open shells need new
    # session to pick up the values. BAT_THEME is read by bat at startup;
    # VIVID_THEME is read by .config/fish/conf.d/10-colors.fish at fish
    # startup to regenerate LS_COLORS via `vivid generate`. fzf colors are
    # palette-symbolic (ANSI 0–15 refs) and auto-adapt via Ghostty's
    # 16-color palette — no env var needed.
    set -Ux BAT_THEME $bat_theme
    set -Ux VIVID_THEME $vivid_theme

    # Live reloads. All swallowed silently because the tool may not be
    # running (e.g. ghostty in a different session, no tmux server yet).
    tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null
    tmux refresh-client -S                    2>/dev/null
    ghostty +reload                           2>/dev/null

    echo "theme → $name"
    echo "  live:    tmux + helpers, starship (next prompt), glow, delta"
    echo "  ghostty: cmd+ctrl+shift+r in Ghostty (ghostty +reload was already attempted)"
    echo "  restart: bat + ls colors (new shells for \$BAT_THEME / \$VIVID_THEME), nvim, gh-dash, lnav"
end
