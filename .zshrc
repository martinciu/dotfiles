# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export EDITOR=vim

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git nvm brew rbenv node)

source "$ZSH/oh-my-zsh.sh"

# ─── No bells ───────────────────────────────
unsetopt BEEP        # shell errors
unsetopt HIST_BEEP   # history expansion errors
unsetopt LIST_BEEP   # ambiguous completion

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ─── Colors & appearance ────────────────────
# LS_COLORS for eza (and GNU ls if present); BSD `\ls` keeps OMZ default LSCOLORS.
command -v vivid >/dev/null 2>&1 && export LS_COLORS="$(vivid generate solarized-dark)"

# Use bat as MANPAGER when available; MANROFFOPT=-c keeps ANSI sequences intact.
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p --paging=always'"
  export MANROFFOPT="-c"
fi

# zsh-autosuggestions: dim ghost text, readable on Solarized Dark.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# fzf — Solarized Dark palette.
export FZF_DEFAULT_OPTS='
  --color=fg:#839496,bg:#002b36,hl:#268bd2
  --color=fg+:#eee8d5,bg+:#073642,hl+:#268bd2
  --color=info:#b58900,prompt:#dc322f,pointer:#d33682
  --color=marker:#2aa198,spinner:#dc322f,header:#586e75'

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Per-machine config (sets PROJECTS_HOME and any local PATH/env overrides).
# Sourced after .zshrc's PATH appends so .zshrc.local's appends still win
# precedence; sourced before any function or precmd that uses $PROJECTS_HOME.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

autoload -U add-zsh-hook
load-nvmrc() {
  local node_version
  node_version="$(nvm version)"
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
if typeset -f nvm > /dev/null 2>&1; then
  add-zsh-hook chpwd load-nvmrc
  load-nvmrc
fi

# Force Claude Code to emit truecolor inside tmux (it downgrades to a 256-color
# palette by default when $TMUX is set). See anthropics/claude-code#36785.
[[ -n $TMUX ]] && export CLAUDE_CODE_TMUX_TRUECOLOR=1

# Keep _tmux_window_label in sync with scripts/test-tmux-window-label.zsh
_tmux_window_label() {
  emulate -L zsh
  local cmd="$1"
  # Strip leading KEY=value tokens (each followed by whitespace, or end-of-string).
  while [[ $cmd =~ '^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*([[:space:]]+|$)' ]]; do
    cmd="${cmd#$MATCH}"
  done
  local -a words=( ${=cmd} )
  case $#words in
    0) _tmux_window_label_out="" ;;
    1) _tmux_window_label_out="${words[1]}" ;;
    *) _tmux_window_label_out="${words[1]} ${words[2]}" ;;
  esac
}

# Per-pane "last command" recorder. tmux.conf reads @last_cmd via
# automatic-rename-format so the window name follows the active pane.
_tmux_record_last_cmd() {
  [[ -z $TMUX ]] && return
  _tmux_window_label "$1"
  [[ -z $_tmux_window_label_out ]] && return
  tmux set -p @last_cmd "$_tmux_window_label_out"
}
add-zsh-hook preexec _tmux_record_last_cmd

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keep in sync with scripts/test-prompt-context.zsh
_p9k_project_context() {
  local projects="$PROJECTS_HOME"
  if [[ -n $TMUX && $PWD == ${projects}/?* ]]; then
    local rel="${PWD#${projects}/}"
    local -a parts=("${(@s:/:)rel}")
    local out="${parts[1]}"
    local i
    for (( i=2; i<${#parts[@]}; i++ )); do
      out+="/${parts[i][1]}"
    done
    (( ${#parts[@]} > 1 )) && out+="/${parts[-1]}"
    _p9k_project_path="$out"
    typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='*'
  else
    unset _p9k_project_path
    typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
  fi
}
add-zsh-hook chpwd _p9k_project_context
precmd_functions=(_p9k_project_context ${precmd_functions:#_p9k_project_context})

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
[[ -f ~/.secrets ]] && source ~/.secrets

# ─── Aliases (color-aware tools) ────────────
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  less() {
    if [[ -t 0 ]]; then
      command bat --paging=always "$@"
    else
      command bat --paging=always --plain "$@"
    fi
  }
fi
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons'
  alias ll='eza -lh --git --icons --group-directories-first'
  alias la='ll -a'
fi
if command -v glow >/dev/null 2>&1; then
  alias md='glow --style $HOME/.config/glow/glamour.json'
  alias mdp='md -p'
fi
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vi='command vim'
  alias vimdiff='vim -d'
fi

# ─── Plugins (order matters) ─────────────────────────────────────
# Required order:
#   fzf shell integration  → binds ^I; must come first so subsequent
#                            plugins that wrap completion can chain to it
#   Alt-C unbind           → adjacent to fzf since it removes a binding fzf set
#   zoxide                 → independent; doesn't bind ^I or wrap widgets
#   zsh-autosuggestions    → wraps widgets; must be after fzf integration
#   zsh-syntax-highlighting → MUST be last (wraps every other widget)

# fzf shell integration (Ctrl-R history, Ctrl-T file picker).
[[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]] && \
  source /opt/homebrew/opt/fzf/shell/completion.zsh
[[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && \
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
# Alt-C is reserved for Polish diacritics; remove fzf's cd-widget binding in
# every keymap fzf might have bound it in.
bindkey -M emacs -r '^[c' 2>/dev/null
bindkey -M viins -r '^[c' 2>/dev/null
bindkey -M vicmd -r '^[c' 2>/dev/null

# zoxide — frecency-ranked `cd` (`z foo`). The sesh picker no longer
# reads zoxide (see tmux.conf: `sesh picker ... -c -t -T`), so these
# excludes exist purely for `z` discipline: `z lib` should not jump
# into ~/Library, `z config` should not jump into ~/.config, etc.
# _ZO_EXCLUDE_DIRS is colon-separated globs (per `man zoxide`).
if command -v zoxide >/dev/null 2>&1; then
  export _ZO_EXCLUDE_DIRS="$HOME:$HOME/Downloads/*:$HOME/.config/*:$HOME/Library/*"
  eval "$(zoxide init zsh)"
fi

# fzf-tab — replace zsh's default completion menu with fzf.
# Must be sourced AFTER fzf shell integration (loses ^I race otherwise) and
# BEFORE zsh-autosuggestions / zsh-syntax-highlighting (both wrap widgets).
[[ -f /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh ]] && \
  source /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh
# OMZ sets `menu select`; fzf-tab needs this disabled to capture completions.
zstyle ':completion:*' menu no
# Group completions by tag with a labeled header.
zstyle ':completion:*:descriptions' format '[%d]'
# Filename colors in the picker — inherit vivid's Solarized palette via LS_COLORS.
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Inherit FZF_DEFAULT_OPTS so the picker matches Ctrl-R / Ctrl-T styling.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# Switch between completion groups.
zstyle ':fzf-tab:*' switch-group '<' '>'
# Preview directory contents when completing `cd`.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'

[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting MUST be the last sourced plugin.
[[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
