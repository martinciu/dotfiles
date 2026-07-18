# Moshi (iPhone/iPad) logins land in a bar-less grouped twin of `notes`
# (#362, #364). Twin creation lives tmux-side in tmux-phone-twin (#366),
# shared with the client-attached hook that covers Moshi's session-picker
# path (which never spawns fish). This file keeps only the login-shell
# entry: MOSHI_CLIENT=1 (Moshi's opt-in env toggle) -> ensure the default
# target exists -> attach straight into the twin (no bar flash). Numbered
# 50: needs PATH from 00-env.fish; later conf.d files never load in this
# shell (exec replaces it) — tmux panes spawn fresh, fully-configured
# shells anyway.
if status is-interactive; and not set -q TMUX; and test "$MOSHI_CLIENT" = 1
    tmux has-session -t =notes 2>/dev/null; or tmux new-session -d -s notes

    set -l twin (~/.config/tmux/bin/tmux-phone-twin notes)
    if test -n "$twin"
        # destroy-unattached only after this client is inside: set on the
        # detached twin it could be reaped before the attach lands.
        exec tmux attach-session -t "=$twin" \; set destroy-unattached on
    end
    # Twin machinery failed — degrade to a bar-ful direct attach (#364
    # pre-twin behavior): usable, never locked out.
    exec tmux new-session -A -s notes
end
