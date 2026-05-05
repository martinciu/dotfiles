# Powerlevel10k prompt + project-context segment.
# Function on top, p10k source + hook registration below the test guard.

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

[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -U add-zsh-hook
add-zsh-hook chpwd _p9k_project_context
precmd_functions=(_p9k_project_context ${precmd_functions:#_p9k_project_context})
