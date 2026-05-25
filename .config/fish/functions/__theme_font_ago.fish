function __theme_font_ago --argument-names secs \
        --description 'Format seconds as a single top-unit "N ago"'
    set -l s (math -- "floor($secs)")
    if test "$s" -lt 60
        printf 'just now'
    else if test "$s" -lt 3600
        printf '%dm ago' (math -- "floor($s / 60)")
    else if test "$s" -lt 86400
        printf '%dh ago' (math -- "floor($s / 3600)")
    else
        printf '%dd ago' (math -- "floor($s / 86400)")
    end
end
