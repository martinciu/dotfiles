function __font_set_readout --description 'Print current font family + weight + size + when set'
    set -l cur (__font_set_current)
    if test -z "$cur"
        echo "font → unknown (no active symlink)"
        return 0
    end
    set -l extra
    set -l wf ~/.config/ghostty/font-weight.ghostty
    set -l sf ~/.config/ghostty/font-size.ghostty
    if test -f "$wf"
        set -l w (string replace -r '^font-style\s*=\s*' '' < "$wf" | string trim)
        test -n "$w"; and set -a extra "weight $w"
    end
    if test -f "$sf"
        set -l s (string replace -r '^font-size\s*=\s*' '' < "$sf" | string trim)
        test -n "$s"; and set -a extra "size $s"
    end
    if test (count $extra) -gt 0
        printf 'font → %s  (%s)\n' $cur (string join ', ' $extra)
    else
        echo "font → $cur"
    end
    set -l row (__theme_font_history font-set (__font_set_names) | string match -r "^.+\t$cur\$" | tail -1)
    if test -z "$row"
        echo "set: unknown (before history)"
        return 0
    end
    set -l ts (string split \t -- $row)[1]
    set -l now (test -n "$THEME_FONT_STATS_NOW"; and echo $THEME_FONT_STATS_NOW; or date +%s)
    printf 'set: %s (%s)\n' (date -r $ts '+%Y-%m-%d %H:%M') (__theme_font_ago (math -- "$now - $ts"))
end
