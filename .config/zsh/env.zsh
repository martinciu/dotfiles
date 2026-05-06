# Locale, EDITOR, PATH, MANPAGER, no-bells.
# All side-effect (env exports + unsetopt). Tests don't source this file.

export EDITOR=vim

# ─── No bells ───────────────────────────────
unsetopt BEEP        # shell errors
unsetopt HIST_BEEP   # history expansion errors
unsetopt LIST_BEEP   # ambiguous completion

# ─── Key bindings ──────────────────────────────
bindkey -e  # emacs mode (zsh defaults to vi when EDITOR contains 'vi')

# ─── History ───────────────────────────────────
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# ─── Shell behavior ───────────────────────────
setopt ALWAYS_TO_END
setopt AUTO_PUSHD
setopt COMPLETE_IN_WORD
setopt INTERACTIVE_COMMENTS
setopt LONG_LIST_JOBS
setopt NO_FLOW_CONTROL
setopt PROMPT_SUBST
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_MINUS

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Use bat as MANPAGER when available; MANROFFOPT=-c keeps ANSI sequences intact.
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p --paging=always'"
  export MANROFFOPT="-c"
fi

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"
