# Powerlevel10k instant prompt — must stay near top of file. Initialization
# code that may require console input (password prompts, [y/n] confirmations,
# etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

autoload -Uz compinit && compinit

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# Split modules — load order matters; see plugins.zsh header for plugin order.
ZDOTFILES="${HOME}/.config/zsh"
source "$ZDOTFILES/env.zsh"
source "$ZDOTFILES/colors.zsh"

# Per-machine config (sets PROJECTS_HOME and any local PATH/env overrides).
# Sourced after env.zsh PATH appends so .zshrc.local's appends still win
# precedence; sourced before any function or precmd that uses $PROJECTS_HOME.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

source "$ZDOTFILES/mise.zsh"
source "$ZDOTFILES/tmux-hooks.zsh"
source "$ZDOTFILES/modern-reminder.zsh"
source "$ZDOTFILES/prompt.zsh"
source "$ZDOTFILES/aliases.zsh"
source "$ZDOTFILES/plugins.zsh"

[[ -f ~/.secrets ]] && source ~/.secrets
