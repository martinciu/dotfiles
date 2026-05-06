# Polyglot runtime version manager (Node + Ruby). mise's `activate`
# registers a chpwd hook that auto-switches versions per .nvmrc /
# .ruby-version / .tool-versions.

[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

if command -v mise > /dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
