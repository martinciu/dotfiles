# brew shellenv. conf.d runs for non-interactive shells too, so child
# processes inherit PATH. Guarded so the same file loads on Linux (the
# sandbox image), where Homebrew is absent — mise + fish_add_path below
# cover PATH there.
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
end

set -gx EDITOR vim
set -gx LANG en_US.UTF-8 # fallback for any LC_* you don't set
set -gx LC_MESSAGES en_US.UTF-8 # English UI / error text
set -gx LC_CTYPE en_US.UTF-8 # character classification
set -gx LC_COLLATE en_US.UTF-8 # sort order (avoids ą interleaving)
set -gx LC_TIME pl_PL.UTF-8 # Polish dates, week starts Monday
set -gx LC_NUMERIC pl_PL.UTF-8 # 1 234,56 instead of 1,234.56

# Kill the default "Welcome to fish, the friendly interactive shell" banner.
# `-g` (not `-U`) so this conf.d file stays the source of truth — flipping
# the line here takes effect on the next shell start without a manual
# `set -e fish_greeting`.
set -g fish_greeting ''

# Bell parity (CLAUDE.md → "Bells are silenced at every layer"). Fish
# doesn't ring the bell on common events (completion miss, backspace at
# an empty line, etc.). Any `\a` it does emit is consumed by Ghostty's
# `bell-features =` and tmux's `bell-action none` upstream. Documented
# here so the per-shell layer is accounted for.

if command -q bat
    set -gx MANPAGER 'sh -c "col -bx | bat -l man -p --paging=always"'
    set -gx MANROFFOPT -c
end

fish_add_path -gPm $HOME/.local/bin $HOME/.cargo/bin

# Ghostty exports COLORTERM=truecolor on the Mac, but `docker exec` forwards
# only TERM — so inside the sandbox COLORTERM is empty and 24-bit-gating tools
# (delta, starship, glow, btop, bat) fall back to 256-color. Backfill it when
# missing so RGB output matches the host; the guard makes this a no-op on the
# Mac (Ghostty already set it). nvim (termguicolors) and vivid's LS_COLORS are
# already 24-bit, so they're unaffected either way.
set -q COLORTERM; or set -gx COLORTERM truecolor

# Force Claude Code truecolor inside tmux. Single env line; the only tmux
# integration that survives B-scope.
if test -n "$TMUX"
    set -gx CLAUDE_CODE_TMUX_TRUECOLOR 1
end
