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
    switch $name
        case mocha
            set bat_theme "Catppuccin Mocha"
        case dracula
            set bat_theme "Dracula"
        case gruvbox
            set bat_theme "gruvbox-dark"
        case '*'
            set bat_theme "Solarized (dark)"
    end

    # Flip symlinks. -sfn replaces the link atomically.
    ln -sfn $name.tmux              ~/.config/themes/current.tmux
    ln -sfn delta-$name.gitconfig   ~/.config/themes/delta-current.gitconfig
    ln -sfn theme-$name.ghostty     ~/.config/ghostty/theme.ghostty
    ln -sfn starship-$name.toml     ~/.config/starship.toml
    ln -sfn glamour-$name.json      ~/.config/glow/glamour.json
    ln -sfn config-$name.yml        ~/.config/gh-dash/config.yml
    ln -sfn theme-$name.json        ~/.config/lnav/configs/installed/theme.json

    # Persisted env var; survives shell restarts. Open shells need new
    # session to pick up the value.
    set -Ux BAT_THEME $bat_theme

    # Live reloads. All swallowed silently because the tool may not be
    # running (e.g. ghostty in a different session, no tmux server yet).
    tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null
    tmux refresh-client -S                    2>/dev/null
    ghostty +reload                           2>/dev/null

    echo "theme → $name"
    echo "  live:    tmux + helpers, starship (next prompt), glow, delta"
    echo "  ghostty: cmd+ctrl+shift+r in Ghostty (ghostty +reload was already attempted)"
    echo "  restart: bat (new shells for \$BAT_THEME), nvim, gh-dash, lnav"
end
