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

_tmux_rename() {
  [[ -z $TMUX ]] && return
  local cmd="${1%% *}"
  [[ -z $cmd ]] && return
  tmux rename-window -- "$cmd"
}
add-zsh-hook preexec _tmux_rename

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
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons'
  alias ll='eza -lh --git --icons --group-directories-first'
  alias la='ll -a'
fi

# ─── Plugins (order matters; syntax-highlighting MUST be last) ─
[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
