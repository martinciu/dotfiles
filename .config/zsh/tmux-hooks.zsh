# Per-pane tmux user-options driven by zsh hooks:
#   @last_cmd   — preexec, drives window name (automatic-rename-format)
#   @ssh_target — preexec/precmd, drives Ghostty tab title (set-titles-string)
# Functions on top, hook registration + CLAUDE_CODE_TMUX_TRUECOLOR below the
# test guard.

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

_tmux_record_last_cmd() {
  [[ -z $TMUX ]] && return
  _tmux_window_label "$1"
  [[ -z $_tmux_window_label_out ]] && return
  tmux set -p @last_cmd "$_tmux_window_label_out"
}

# Per-pane SSH-target recorder (Ghostty tab title overlay). preexec stamps
# @ssh_target with the canonical user@hostname while an `ssh` command is
# foreground; precmd clears it on the next prompt. tmux.conf's set-titles-string
# reads @ssh_target so the Ghostty tab shows " user@host" during ssh and
# falls back to <session>:<window> otherwise. Resolution uses `ssh -G` so
# ~/.ssh/config Host aliases / default Users canonicalize correctly.
_tmux_record_ssh_target() {
  [[ -z ${TMUX:-} ]] && return
  local -a tokens=(${=1})
  [[ ${tokens[1]:-} == ssh ]] || return
  local resolved
  resolved=$(eval "ssh -G ${1#ssh}" 2>/dev/null) || return
  local host user
  host=${${(M)${(f)resolved}:#hostname *}#hostname }
  user=${${(M)${(f)resolved}:#user *}#user }
  [[ -n $user && -n $host ]] || return
  tmux set -p @ssh_target "$user@$host"
  tmux refresh-client -S
}

_tmux_clear_ssh_target() {
  [[ -z ${TMUX:-} ]] && return
  [[ -z $(tmux show -p -v @ssh_target 2>/dev/null) ]] && return
  tmux set -p -u @ssh_target
  tmux refresh-client -S
}

[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

# Force Claude Code to emit truecolor inside tmux (it downgrades to a 256-color
# palette by default when $TMUX is set). See anthropics/claude-code#36785.
[[ -n $TMUX ]] && export CLAUDE_CODE_TMUX_TRUECOLOR=1

autoload -U add-zsh-hook
add-zsh-hook preexec _tmux_record_last_cmd
add-zsh-hook preexec _tmux_record_ssh_target
add-zsh-hook precmd  _tmux_clear_ssh_target
