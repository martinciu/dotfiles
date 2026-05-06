if command -q vivid
    set -gx LS_COLORS (vivid generate solarized-dark)
end

set -gx FZF_DEFAULT_OPTS '
  --color=fg:#839496,bg:#002b36,hl:#268bd2
  --color=fg+:#eee8d5,bg+:#073642,hl+:#268bd2
  --color=info:#b58900,prompt:#dc322f,pointer:#d33682
  --color=marker:#2aa198,spinner:#dc322f,header:#586e75'

# Ghost-text autosuggestions — dim, readable on Solarized Dark.
set -g fish_color_autosuggestion brblack

# Solarized syntax-highlighting palette (replaces zsh-syntax-highlighting).
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
