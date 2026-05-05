# Color-aware modern-tool aliases (bat, eza, glow, procs, nvim, btop, difft)
# plus the bat-backed `less()` function.
# All side-effect; tests don't source this file.
[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  less() {
    if [[ -t 0 ]]; then
      command bat --paging=always "$@"
    else
      command bat --paging=always --plain "$@"
    fi
  }
fi
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons'
  alias ll='eza -lh --git --icons --group-directories-first'
  alias la='ll -a'
fi
if command -v glow >/dev/null 2>&1; then
  alias md='glow --style $HOME/.config/glow/glamour.json'
  alias mdp='md -p'
fi
if command -v procs >/dev/null 2>&1; then
  alias ps='procs'
  alias psh='procs --load-config $HOME/.config/procs/procs-heavy.toml'
fi
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vi='command vim'
  alias vimdiff='vim -d'
fi
if command -v btop >/dev/null 2>&1; then
  alias top='btop'
fi
if command -v difft >/dev/null 2>&1; then
  alias diff='difft'
fi
