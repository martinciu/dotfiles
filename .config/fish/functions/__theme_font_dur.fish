function __theme_font_dur --argument-names secs \
        --description 'Format seconds as 3d 9h 24m / 1h 5m / 1m 12s / 42s'
    set -l s (math -- "floor($secs)")
    test "$s" -lt 0; and set s 0
    set -l d (math -- "floor($s / 86400)")
    set -l h (math -- "floor($s % 86400 / 3600)")
    set -l m (math -- "floor($s % 3600 / 60)")
    set -l sec (math -- "$s % 60")
    if test "$d" -gt 0
        printf '%dd %dh %dm' $d $h $m
    else if test "$h" -gt 0
        printf '%dh %dm' $h $m
    else if test "$m" -gt 0
        printf '%dm %ds' $m $sec
    else
        printf '%ds' $sec
    end
end
