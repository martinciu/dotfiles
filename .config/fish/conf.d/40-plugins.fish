# fzf shell integration — Ctrl-R history, Ctrl-T file picker, Alt-C cd.
if command -q fzf
    fzf --fish | source
end

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
