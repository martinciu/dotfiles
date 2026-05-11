function __ghostty_reload \
        --description 'Trigger Ghostty config reload via System Events when Ghostty is frontmost; echo a status line'
    # Ghostty has no CLI reload action — the only path is the per-surface
    # `reload_config` keybind (cmd+ctrl+shift+r in this config). We
    # synthesize that keystroke via System Events, which routes to the
    # frontmost app. Skip when Ghostty isn't frontmost so we don't
    # inject the keystroke into a different app. First call may prompt
    # for Accessibility permission on the terminal hosting fish.
    set -l frontmost (osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
    if test (string lower -- $frontmost) = ghostty
        osascript -e 'tell application "System Events" to keystroke "r" using {command down, control down, shift down}' 2>/dev/null
        echo "cmd+ctrl+shift+r sent to focused window (other windows: manual)"
    else
        echo "hit cmd+ctrl+shift+r per window (frontmost is $frontmost, not Ghostty)"
    end
end
