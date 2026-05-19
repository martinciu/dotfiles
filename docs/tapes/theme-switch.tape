# theme-switch demo — cycles `theme-set` across Solarized -> Dracula -> Gruvbox.
# vhs records inside a ttyd-spawned terminal, NOT live Ghostty, so the recorder
# background palette is fixed at top-of-tape. What you see swap mid-recording is
# the tmux statusbar chips, the starship prompt accent, and the right-pane bat
# output repainting on each switch.

# Output two formats from one run
Output docs/tapes/theme-switch.gif
Output docs/tapes/theme-switch.webm

# Recording environment — locked for the tape's lifetime
Set Shell fish
Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 16
Set Width 1600
Set Height 900
Set Theme "Builtin Solarized Dark"
Set Padding 24
Set Framerate 30
Set PlaybackSpeed 1.0

Require tmux
Require bat

# Hidden setup: start tmux, vertical 55/45 split, bat the aliases file in the
# right pane so the syntax palette is visible and repaints on each switch.
Hide
Type "tmux new-session -A -s vhs"
Enter
Sleep 800ms
Type "tmux split-window -h -p 45"
Enter
Sleep 400ms
Type "tmux select-pane -t 0"
Enter
Sleep 200ms
Type "tmux send-keys -t 1 'bat ~/.config/fish/conf.d/30-aliases.fish' Enter"
Enter
Sleep 1s
Show

# Cycle: Solarized -> Dracula -> Gruvbox -> Solarized.
Sleep 1500ms
Type "theme-set dracula"
Sleep 300ms
Enter
Sleep 2500ms
Type "tmux send-keys -t 1 'bat ~/.config/fish/conf.d/30-aliases.fish' Enter"
Enter
Sleep 1500ms
Type "theme-set gruvbox"
Sleep 300ms
Enter
Sleep 2500ms
Type "tmux send-keys -t 1 'bat ~/.config/fish/conf.d/30-aliases.fish' Enter"
Enter
Sleep 1500ms
Type "theme-set solarized"
Sleep 300ms
Enter
Sleep 2000ms
