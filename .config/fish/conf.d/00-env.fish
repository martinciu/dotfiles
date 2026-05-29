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

# eza loads theme.yml only from $EZA_CONFIG_DIR. Despite the man page claiming a
# ~/.config/eza default, eza 0.23 does NOT read theme.yml from that fallback —
# the var must be set explicitly or `ls`/`ll` silently ignore theme-set's flip.
# Unconditional (not `command -q eza`-guarded): in the sandbox eza is a mise shim
# not yet on PATH when 00-env runs (mise activates in 20-mise.fish), and the
# export is a harmless no-op when eza is absent.
set -gx EZA_CONFIG_DIR $HOME/.config/eza

fish_add_path -gPm $HOME/.local/bin $HOME/.cargo/bin

# nvimpager as the general $PAGER — smooth, colored paging (e.g. glow's
# markdown ANSI). man (MANPAGER=bat above) and git (core.pager=delta) win for
# their own output. Guarded so shells without nvimpager stay clean. MUST come
# after the fish_add_path above: in the sandbox nvimpager is installed into
# ~/.local/bin, so `command -q` only finds it once that dir is on PATH (on the
# Mac it's a Homebrew path already present, so the order is moot there).
if command -q nvimpager
    set -gx PAGER nvimpager
end

# Ghostty exports COLORTERM=truecolor on the Mac, but `docker exec` forwards
# only TERM — so inside the sandbox COLORTERM is empty and 24-bit-gating tools
# (delta, starship, glow, btop, bat) fall back to 256-color. Backfill it when
# missing so RGB output matches the host; the guard makes this a no-op on the
# Mac (Ghostty already set it). nvim (termguicolors) and vivid's LS_COLORS are
# already 24-bit, so they're unaffected either way.
set -q COLORTERM; or set -gx COLORTERM truecolor

# OrbStack `sandbox machine` mounts the Mac home at /Users, and orb starts every
# shell with cwd set to the translated Mac path. mise (activated in 20-mise.fish)
# would then walk up into /Users and choke on the Mac's untrusted, Mac-specific
# global config — breaking activation so starship and every shim drop off PATH.
# Tell mise to ignore that whole subtree. Guard fires only in the machine: Mac is
# Darwin (skips), the container has no /Users mount (skips). Must run before
# 20-mise.fish, which 00-env.fish does.
if test (uname) = Linux; and test -d /Users
    set -gx MISE_IGNORED_CONFIG_PATHS /Users
end

# Tweaks that only apply inside tmux (no-ops elsewhere, incl. the sandbox where
# $TMUX is unset).
if test -n "$TMUX"
    # Force Claude Code truecolor — the only tmux integration that survives
    # B-scope.
    set -gx CLAUDE_CODE_TMUX_TRUECOLOR 1

    # TERM is tmux-256color here, but Ghostty still exports TERMINFO pointing at
    # its app bundle (which ships only ghostty/xterm-ghostty). nsf/termbox-go —
    # ctop and other legacy TUIs — treats TERMINFO as exclusive ("no other
    # directory should be searched"), so it can't find tmux-256color and panics
    # with "termbox: unsupported terminal". Clearing it lets termbox fall back to
    # /usr/share/terminfo, where tmux-256color lives. Safe: ncurses tools already
    # fall back there, and Ghostty's own entries are mirrored in ~/.terminfo (and
    # never used inside tmux anyway).
    set -e TERMINFO
end
