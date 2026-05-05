# Discoverability nudge for default-to-modern tool pairs that this setup
# leaves intentionally unaliased (tail/tspin, grep/rg, curl/xh). One-line
# hint after the first invocation per zsh process, per command.
# Disable by commenting out `export MODERN_REMINDER=1` at the bottom.

typeset -gA _modern_reminder_pairs=(
  [tail]=tspin
  [grep]=rg
  [curl]=xh
)
typeset -gA _modern_reminder_hints=(
  [tail]="%F{yellow}\uF0EB%f tspin is a modern alternative to tail. Try 'tspin -f app.log'."
  [grep]="%F{yellow}\uF0E7%f rg is a modern alternative to grep."
  [curl]="%F{yellow}\uF427%f xh (HTTPie-compatible) is a modern alternative to curl."
)
typeset -gA _modern_reminder_seen
typeset -g _modern_reminder_pending=""

_modern_reminder_preexec() {
  [[ -z ${MODERN_REMINDER:-} ]] && return
  _modern_reminder_pending=""
  local -a tokens=(${(z)1})
  local t base
  for t in "${tokens[@]}"; do
    base="${t##*/}"
    base="${base#\\}"
    if [[ -n "${_modern_reminder_pairs[$base]:-}" ]]; then
      _modern_reminder_pending="$base"
      return
    fi
  done
}

_modern_reminder_precmd() {
  local cmd="$_modern_reminder_pending"
  _modern_reminder_pending=""
  [[ -z ${MODERN_REMINDER:-} ]] && return
  [[ -z $cmd ]] && return
  [[ -n "${_modern_reminder_seen[$cmd]:-}" ]] && return
  local modern="${_modern_reminder_pairs[$cmd]:-}"
  [[ -z $modern ]] && return
  command -v "$modern" >/dev/null 2>&1 || return
  print -P "${_modern_reminder_hints[$cmd]}"
  _modern_reminder_seen[$cmd]=1
}

[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

autoload -U add-zsh-hook
add-zsh-hook preexec _modern_reminder_preexec
add-zsh-hook precmd  _modern_reminder_precmd

export MODERN_REMINDER=1
