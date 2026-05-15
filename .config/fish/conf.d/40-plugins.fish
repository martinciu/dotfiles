# fzf shell integration — Ctrl-R history, Ctrl-T file picker, Alt-C cd.
if command -q fzf
    fzf --fish | source
end

# Show human-readable date (col 1) + command (col 3+) in Ctrl-R history.
# The fzf fish integration emits 3 tab-delimited columns: date, unix timestamp,
# command. Default --with-nth=2.. hides the date and shows the raw timestamp.
# Overriding to 1,3.. drops the unix timestamp column.
set -gx FZF_CTRL_R_OPTS "--with-nth=1,3.."

# Alt-C is reserved for Polish diacritics; remove fzf's cd-widget binding.
bind -e \ec 2>/dev/null

# zoxide — frecency-ranked cd.
if command -q zoxide
    set -gx _ZO_EXCLUDE_DIRS "$HOME:$HOME/Downloads/*:$HOME/.config/*:$HOME/Library/*"
    zoxide init fish | source
end

# worktrunk shell init.
if command -q wt
    wt config shell init fish | source
end
