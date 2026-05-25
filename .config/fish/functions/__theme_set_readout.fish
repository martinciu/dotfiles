function __theme_set_readout --description 'Print current theme + when it was set'
    set -l cur (__theme_set_current)
    if test -z "$cur"
        echo "theme → unknown (no active symlink)"
        return 0
    end
    echo "theme → $cur"
    set -l row (__theme_font_history theme-set (__theme_set_names) | string match -r "\t$cur\$" | tail -1)
    if test -z "$row"
        echo "set: unknown (before history)"
        return 0
    end
    set -l ts (string split \t -- $row)[1]
    set -l now (test -n "$THEME_FONT_STATS_NOW"; and echo $THEME_FONT_STATS_NOW; or date +%s)
    printf 'set: %s (%s)\n' (date -r $ts '+%Y-%m-%d %H:%M') (__theme_font_ago (math -- "$now - $ts"))
end
