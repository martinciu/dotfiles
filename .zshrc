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

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export PROJECTS_HOME="$HOME/code"

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
  local projects="${PROJECTS_HOME:-$HOME/code}"
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
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
