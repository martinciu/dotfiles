# Moshi (iPhone) sessions land in a bar-less grouped twin of `notes` (#362).
# Moshi's opt-in "MOSHI_CLIENT env" toggle exports MOSHI_CLIENT=1 into the
# remote shell before tmux starts — that's the detection hook. Plain SSH and
# local shells are untouched. Numbered 50: needs PATH from 00-env.fish;
# later conf.d files never load in this shell (exec replaces it) — tmux
# panes spawn fresh, fully-configured shells anyway.
if status is-interactive; and not set -q TMUX; and test "$MOSHI_CLIENT" = 1
    # Grouping against a nonexistent session is an error — ensure the target.
    tmux has-session -t notes 2>/dev/null; or tmux new-session -d -s notes

    # tmux-resurrect restores `phone` as an ungrouped full copy of notes
    # (it doesn't understand session groups); `-A` would attach to that
    # stale copy — kill it unless it's genuinely grouped with notes.
    if tmux has-session -t phone 2>/dev/null
        test "$(tmux display-message -p -t phone '#{session_group}')" = notes; or tmux kill-session -t phone
    end

    # The twin shares notes' windows but owns its session options: status
    # off hides the bar for the phone only; destroy-unattached keeps
    # tmux ls clean after the phone drops. exec: detach ends the connection.
    exec tmux new-session -A -s phone -t notes \; set status off \; set destroy-unattached on
end
