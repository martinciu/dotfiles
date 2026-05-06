# brew shellenv — replaces .zprofile's role on the fish side. conf.d
# runs for non-interactive shells too, so child processes inherit PATH.
eval (/opt/homebrew/bin/brew shellenv)

set -gx EDITOR vim
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# Kill the default "Welcome to fish, the friendly interactive shell" banner.
# `-g` (not `-U`) so this conf.d file stays the source of truth — flipping
# the line here takes effect on the next shell start without a manual
# `set -e fish_greeting`.
set -g fish_greeting ''

# Bell parity (CLAUDE.md → "Bells are silenced at every layer"). Fish has
# no `unsetopt BEEP` equivalent — fish doesn't ring the bell on the events
# zsh does (completion miss, backspace at empty line, etc.). Any `\a` that
# fish does emit is consumed by Ghostty's `bell-features =` and tmux's
# `bell-action none` upstream. Documented here so the per-shell layer is
# accounted for.

if command -q bat
    set -gx MANPAGER 'sh -c "col -bx | bat -l man -p --paging=always"'
    set -gx MANROFFOPT -c
end

fish_add_path -gP $HOME/.local/bin $HOME/.cargo/bin

# Force Claude Code truecolor inside tmux. Single env line; the only tmux
# integration that survives B-scope.
if test -n "$TMUX"
    set -gx CLAUDE_CODE_TMUX_TRUECOLOR 1
end
