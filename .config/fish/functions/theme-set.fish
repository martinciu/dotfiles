function theme-set --description 'Switch colour scheme between solarized, mocha, frappe, dracula, gruvbox, tokyo-night, nord, latte, rose-pine, and rose-pine-moon'
    set -l name $argv[1]
    switch $name
        case solarized mocha frappe dracula gruvbox tokyo-night nord latte rose-pine rose-pine-moon
            # OK
        case '*'
            echo "Usage: theme-set <solarized|mocha|frappe|dracula|gruvbox|tokyo-night|nord|latte|rose-pine|rose-pine-moon>" >&2
            return 1
    end

    set -l bat_theme
    set -l vivid_theme
    switch $name
        case mocha
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "catppuccin-mocha"
        case frappe
            set bat_theme "Catppuccin Frappé"
            set vivid_theme "catppuccin-frappe"
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
        case nord
            # bat 0.26+ ships `Nord` built-in (capitalized, no hyphen).
            set bat_theme "Nord"
            set vivid_theme "nord"
        case latte
            set bat_theme "Catppuccin Latte"
            set vivid_theme "catppuccin-latte"
        case rose-pine
            # bat 0.26 has no rose-pine syntax theme; fall back to
            # Catppuccin Mocha (closest pastel-on-dark; Tokyo Night
            # precedent).
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "rose-pine"
        case rose-pine-moon
            # Same bat fallback as Main; vivid ships moon natively.
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "rose-pine-moon"
        case '*'
            set bat_theme "Solarized (dark)"
            set vivid_theme "solarized-dark"
    end

    # Flip symlinks. -sfn replaces the link atomically. Each flip is
    # existence-guarded on the source: partial-coverage themes (e.g. Latte
    # ships only ghostty/tmux/starship) coexist with full-coverage ones
    # without a bespoke `case` branch. Five themes have every variant present
    # and pass every guard; Latte has four guards fail and those tools keep
    # their previous symlinks pointing at the most-recent dark theme.
    # Future tier-1 extensions for Latte are purely additive — drop the
    # variant file in, the guard auto-engages, no theme-set changes.
    test -f ~/.config/themes/$name.tmux \
        ; and ln -sfn $name.tmux ~/.config/themes/current.tmux
    test -f ~/.config/themes/delta-$name.gitconfig \
        ; and ln -sfn delta-$name.gitconfig ~/.config/themes/delta-current.gitconfig
    test -f ~/.config/ghostty/theme-$name.ghostty \
        ; and ln -sfn theme-$name.ghostty ~/.config/ghostty/theme.ghostty
    test -f ~/.config/starship-$name.toml \
        ; and ln -sfn starship-$name.toml ~/.config/starship.toml
    test -f ~/.config/glow/glamour-$name.json \
        ; and ln -sfn glamour-$name.json ~/.config/glow/glamour.json
    test -f ~/.config/lnav/configs/installed/theme-$name.json \
        ; and ln -sfn theme-$name.json ~/.config/lnav/configs/installed/theme.json

    # gh-dash live config is a generated real file, not a symlink.
    # base.yml has no `theme:` key; theme-colors-$name.yml has only `theme:` —
    # plain concatenation produces valid YAML, no merge engine needed.
    # Existence-guarded like the symlink flips above: when no Latte variant
    # exists, gh-dash keeps its previous config.yml.
    if test -f ~/.config/gh-dash/theme-colors-$name.yml
        cat \
            ~/.config/gh-dash/config-base.yml \
            ~/.config/gh-dash/theme-colors-$name.yml \
            > ~/.config/gh-dash/config.yml
    end

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
    echo "  live:    tmux + helpers, starship (next prompt), glow, delta, ghostty (via keystroke)"
    echo "  restart: bat + ls colors (new shells for \$BAT_THEME / \$VIVID_THEME), nvim, gh-dash, lnav"

    # Fire the ghostty config reload (cmd+ctrl+shift+r via System Events when
    # Ghostty is frontmost). Surface the helper's status so the user can tell
    # whether the keystroke fired — silent reload is indistinguishable from a
    # missing Accessibility permission, which is the usual culprit when
    # Ghostty's colors don't update after theme-set.
    __ghostty_reload | sed 's/^/  ghostty: /'
end
