function __theme_font_history --description 'Parse fish_history → sorted "epoch\tname" for valid names of a command'
    set -l cmd $argv[1]
    set -l valid $argv[2..-1]

    set -l hist $FISH_HISTORY_FILE
    test -z "$hist"; and set hist $__fish_user_data_dir/fish_history
    test -f "$hist"; or set hist ~/.local/share/fish/fish_history
    test -f "$hist"; or return 0

    set -l rows
    set -l pending_name
    while read -l line
        if set -l m (string match -r "^- cmd: $cmd (\S+)" -- $line)
            # m[2] is the first token after the command name.
            if contains -- $m[2] $valid
                set pending_name $m[2]
            else
                set pending_name ''
            end
        else if test -n "$pending_name"
            if set -l w (string match -r '^\s+when:\s+(\d+)' -- $line)
                set -a rows "$w[2]"\t"$pending_name"
                set pending_name ''
            end
        end
    end <"$hist"

    test (count $rows) -gt 0; and printf '%s\n' $rows | sort -n
end
