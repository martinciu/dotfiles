# Locale, EDITOR, PATH, MANPAGER, no-bells.
# All side-effect (env exports + unsetopt). Tests don't source this file.

export EDITOR=vim

# ─── No bells ───────────────────────────────
unsetopt BEEP        # shell errors
unsetopt HIST_BEEP   # history expansion errors
unsetopt LIST_BEEP   # ambiguous completion

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
