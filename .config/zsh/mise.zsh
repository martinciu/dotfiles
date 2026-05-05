# Polyglot runtime version manager (Node here; Ruby still on rbenv pending
# its own migration). mise's `activate` registers a chpwd hook that
# auto-switches versions per .nvmrc / .tool-versions in Rust.

[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

if command -v mise > /dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
