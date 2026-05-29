function theme-set --description 'Switch colour scheme; bare = show current, --stats = usage report'
    set -l usage "Usage: theme-set <solarized|mocha|frappe|dracula|gruvbox|tokyo-night|nord|latte|rose-pine|rose-pine-moon>
       theme-set            show current theme + when set
       theme-set --stats [--all]   per-theme usage report"

    # --help / -h
    if contains -- -h $argv; or contains -- --help $argv
        echo $usage
        return 0
    end

    # --stats [--all]
    if contains -- --stats $argv
        set -l all 0
        contains -- --all $argv; and set all 1
        set -l cur (__theme_set_current)
        __theme_font_history theme-set (__theme_set_names) \
            | __theme_font_stats_report THEME "$cur" $all (__theme_set_names)
        return 0
    end

    set -l name $argv[1]

    # Bare invocation → current selection readout.
    if test -z "$name"
        __theme_set_readout
        return 0
    end

    if not contains -- $name (__theme_set_names)
        echo $usage >&2
        return 1
    end

    set -l bat_theme
    set -l vivid_theme
    set -l btop_theme
    switch $name
        case mocha
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "catppuccin-mocha"
            set btop_theme "catppuccin_mocha"
        case frappe
            set bat_theme "Catppuccin Frappé"
            set vivid_theme "catppuccin-frappe"
            set btop_theme "catppuccin_frappe"
        case dracula
            set bat_theme "Dracula"
            set vivid_theme "dracula"
            set btop_theme "dracula"
        case gruvbox
            set bat_theme "gruvbox-dark"
            set vivid_theme "gruvbox-dark"
            set btop_theme "gruvbox_dark"
        case tokyo-night
            # bat 0.26 has no tokyonight syntax theme; fall back to
            # Catppuccin Mocha (closest pastel-on-dark in bat's catalogue).
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "tokyonight-storm"
            set btop_theme "tokyo-storm"
        case nord
            # bat 0.26+ ships `Nord` built-in (capitalized, no hyphen).
            set bat_theme "Nord"
            set vivid_theme "nord"
            set btop_theme "nord"
        case latte
            set bat_theme "Catppuccin Latte"
            set vivid_theme "catppuccin-latte"
            set btop_theme "catppuccin_latte"
        case rose-pine
            # bat 0.26 has no rose-pine syntax theme; fall back to
            # Catppuccin Mocha (closest pastel-on-dark; Tokyo Night
            # precedent).
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "rose-pine"
            set btop_theme "rose-pine"
        case rose-pine-moon
            # Same bat fallback as Main; vivid ships moon natively.
            set bat_theme "Catppuccin Mocha"
            set vivid_theme "rose-pine-moon"
            set btop_theme "rose-pine-moon"
        case '*'
            set bat_theme "Solarized (dark)"
            set vivid_theme "solarized-dark"
            set btop_theme "solarized_dark"
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
    test -f ~/.config/btop/themes/$btop_theme.theme \
        ; and ln -sfn $btop_theme.theme ~/.config/btop/themes/current.theme
    test -f ~/.config/eza/eza-$name.yml \
        ; and ln -sfn eza-$name.yml ~/.config/eza/theme.yml

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
    # Gated on FISH_DOTFILES_TEST so the test harness doesn't repaint the
    # live status bar on every flip (same intent as the __ghostty_reload
    # suppression below).
    if not set -q FISH_DOTFILES_TEST
        tmux source-file ~/.config/tmux/tmux.conf 2>/dev/null
        tmux refresh-client -S                    2>/dev/null
    end

    echo "theme → $name"
    echo "  live:    tmux + helpers, starship (next prompt), glow, delta, eza"
    echo "  restart: bat + ls colors (new shells for \$BAT_THEME / \$VIVID_THEME), nvim, gh-dash, lnav, btop"
    # Ghostty 1.3 limitation: reload_config does NOT repaint existing surfaces
    # when `theme` changes — only NEW windows/tabs/splits opened after reload
    # pick up the new palette. Existing windows keep their old theme until a
    # full Ghostty restart (cmd+q + reopen). See ghostty-org/ghostty#1141.
    # We still fire the reload keystroke so subsequent splits/tabs inherit
    # the new theme without restarting; just don't expect the current window
    # to repaint.
    echo "  ghostty: new windows only — existing surfaces keep old theme until restart (ghostty#1141)"
    __ghostty_reload >/dev/null
end
