function __theme_font_stats_report --description 'Aggregate theme/font history rows into a usage report'
    set -l raw 0
    if test "$argv[1]" = --raw
        set raw 1
        set -e argv[1]
    end
    set -l label $argv[1]
    set -l current $argv[2]
    set -l all $argv[3]
    set -l valid $argv[4..-1]

    set -l now $THEME_FONT_STATS_NOW
    test -z "$now"; and set now (date +%s)

    # Read rows (epoch\tname), already sorted ascending by the parser.
    set -l epochs
    set -l names
    while read -l line
        test -z "$line"; and continue
        set -a epochs (string split \t -- $line)[1]
        set -a names (string split \t -- $line)[2]
    end

    if test (count $epochs) -eq 0
        echo "$label: no history yet." >&2
        return 0
    end

    set -l window_start $epochs[1]
    set -l span (math -- "$now - $window_start")
    test "$span" -lt 1; and set span 1

    # Per-selection duration = gap to next; last → now. Aggregate by name.
    set -l agg_names
    set -l agg_total
    set -l agg_sw
    set -l agg_last
    set -l n (count $epochs)
    for i in (seq $n)
        set -l start $epochs[$i]
        set -l stop $now
        test "$i" -lt "$n"; and set stop $epochs[(math $i + 1)]
        set -l dur (math -- "$stop - $start")
        test "$dur" -lt 0; and set dur 0
        set -l name $names[$i]
        set -l idx (contains -i -- $name $agg_names; or echo 0)
        if test "$idx" -eq 0
            set -a agg_names $name
            set -a agg_total $dur
            set -a agg_sw 1
            set -a agg_last $start
        else
            set agg_total[$idx] (math -- "$agg_total[$idx] + $dur")
            set agg_sw[$idx] (math -- "$agg_sw[$idx] + 1")
            test "$start" -gt "$agg_last[$idx]"; and set agg_last[$idx] $start
        end
    end

    # Build sortable lines: total<TAB>last<TAB>name<TAB>sw, sort by total desc
    # then last desc (tie-break newest-first).
    set -l lines
    for i in (seq (count $agg_names))
        set -a lines "$agg_total[$i]\t$agg_last[$i]\t$agg_names[$i]\t$agg_sw[$i]"
    end
    set -l sorted (printf '%b\n' $lines | sort -t\t -k1,1nr -k2,2nr)

    if test "$raw" = 1
        for l in $sorted
            set -l f (string split \t -- $l)
            printf '%s\t%s\t%s\t%s\n' $f[3] $f[1] $f[4] $f[2]
        end
        return 0
    end

    # Human rendering added in Task 5.
end
