# vivid LS_COLORS — theme follows $VIVID_THEME (set by theme-set, default
# solarized-dark). vivid 0.11+ ships solarized-dark, catppuccin-mocha,
# dracula, gruvbox-dark built-in (no vendoring).
if command -q vivid
    set -l vivid_theme solarized-dark
    set -q VIVID_THEME; and set vivid_theme $VIVID_THEME
    set -gx LS_COLORS (vivid generate $vivid_theme)
end

# fzf colors — ANSI palette refs (0-15) that adapt to whatever the
# terminal palette is. Ghostty sets the 16-color palette per theme, so
# fzf re-themes automatically with `theme-set`. -1 = terminal default
# (transparent over Ghostty bg). 4 = blue accent, 8 = bright black
# (selection bg lift), 15 = bright white (selected fg).
set -gx FZF_DEFAULT_OPTS '
  --color=fg:-1,bg:-1,hl:4
  --color=fg+:15,bg+:8,hl+:4
  --color=info:3,prompt:1,pointer:5
  --color=marker:6,spinner:1,header:8'

# Ghost-text autosuggestions — dim, readable on Solarized Dark.
set -g fish_color_autosuggestion brblack

# Solarized syntax-highlighting palette.
set -g fish_color_command       blue
set -g fish_color_param         normal
set -g fish_color_quote         cyan
set -g fish_color_redirection   magenta
set -g fish_color_end           magenta
set -g fish_color_error         red
set -g fish_color_comment       brblack
set -g fish_color_operator      magenta
set -g fish_color_escape        yellow
set -g fish_color_match         --background=brblack
set -g fish_color_search_match  --background=brblack
