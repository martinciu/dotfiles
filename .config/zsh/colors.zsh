# Solarized palettes for ls/eza, fzf, and zsh-autosuggestions ghost text.
# All side-effect (env exports). Tests don't source this file.

# ─── Colors & appearance ────────────────────
# LS_COLORS for eza (and GNU ls if present).
command -v vivid >/dev/null 2>&1 && export LS_COLORS="$(vivid generate solarized-dark)"

# zsh-autosuggestions: dim ghost text, readable on Solarized Dark.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# fzf — Solarized Dark palette.
export FZF_DEFAULT_OPTS='
  --color=fg:#839496,bg:#002b36,hl:#268bd2
  --color=fg+:#eee8d5,bg+:#073642,hl+:#268bd2
  --color=info:#b58900,prompt:#dc322f,pointer:#d33682
  --color=marker:#2aa198,spinner:#dc322f,header:#586e75'
