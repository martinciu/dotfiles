# brew shellenv — replaces .zprofile's role on the fish side. conf.d
# runs for non-interactive shells too, so child processes inherit PATH.
eval (/opt/homebrew/bin/brew shellenv)

set -gx EDITOR vim
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

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
