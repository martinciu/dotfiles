# Auto-switch Node version per-directory via .nvmrc.
# Function on top, hook registration + initial call below the test guard.

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

[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

autoload -U add-zsh-hook
if typeset -f nvm > /dev/null 2>&1; then
  add-zsh-hook chpwd load-nvmrc
  load-nvmrc
fi
