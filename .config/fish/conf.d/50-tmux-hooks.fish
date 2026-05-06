# Per-pane tmux user-options driven by fish hooks:
#   @last_cmd — fish_preexec, drives window name (automatic-rename-format
#               in .config/tmux/tmux.conf reads it).
# Pure helper on top, event-registered recorder below the
# FISH_DOTFILES_TEST guard. Tests source this file with
# FISH_DOTFILES_TEST=1 to load the helper without registering a
# fish_preexec listener.

function _tmux_window_label --argument-names cmd
    # Strip leading KEY=value tokens (each followed by whitespace or end-of-string).
    while string match -rq '^[A-Za-z_][A-Za-z0-9_]*=\S*(\s+|$)' -- $cmd
        set cmd (string replace -r '^[A-Za-z_][A-Za-z0-9_]*=\S*(\s+|$)' '' -- $cmd)
    end
    set -l words (string match -ar '\S+' -- $cmd)
    switch (count $words)
        case 0
            echo ''
        case 1
            echo $words[1]
        case '*'
            echo "$words[1] $words[2]"
    end
end

if not set -q FISH_DOTFILES_TEST
    function _tmux_record_last_cmd --on-event fish_preexec
        test -n "$TMUX"; or return
        set -l label (_tmux_window_label "$argv[1]")
        test -n "$label"; or return
        tmux set -p @last_cmd "$label"
    end
end
