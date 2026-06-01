# glow-backed markdown renderer, word-wrapped to the current terminal/pane width.
#
# glow reads its wrap width once at launch (one-shot + pager modes render and
# exit), so the width reflects the pane size at the moment `md` runs — resize
# the pane and re-run to re-flow. Passing the full $COLUMNS is safe: glow keeps
# a 2-col gutter, so output never hugs the edge. A later user `-w`/`--width`
# wins (cobra takes the last flag), so `md -w 100 file` still overrides.
#
# Piped/redirected output (no tty) drops --width so renders stay deterministic,
# falling back to glow.yml's configured width.
function md --description 'Render markdown via glow, wrapped to the current terminal width'
    set -l style $HOME/.config/glow/glamour.json
    set -l width
    if isatty stdout; and set -q COLUMNS; and test "$COLUMNS" -gt 0
        set width --width $COLUMNS
    end
    glow --style $style $width $argv
end
