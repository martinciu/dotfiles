# Discoverability nudge for default-to-modern tool pairs that this setup
# leaves intentionally unaliased (tail/tspin, grep/rg, curl/xh). One-line
# hint the first time per fish process, per command. Disable by removing
# the `set -gx MODERN_REMINDER 1` line at the bottom.

# Parallel-list catalog (fish has no associative arrays).
# Index N in each list is one (default, modern, glyph, sample-syntax) entry.
set -g _modern_reminder_keys     tail               grep               curl
set -g _modern_reminder_modern   tspin              rg                 xh
set -g _modern_reminder_glyphs   '\uF0EB'           '\uF0E7'           '\uF427'
# Hint text — sample syntax kept in single-quoted segments so the prompt
# doesn't substitute. Empty string => no sample syntax for that pair.
set -g _modern_reminder_samples  "Try 'tspin -f app.log'." "" ""
# Per-shell seen-set (cleared at fish process start, naturally fresh each session).
set -g _modern_reminder_seen

function _modern_reminder_lookup --argument-names cmd
    set -l i 1
    for k in $_modern_reminder_keys
        if test "$k" = "$cmd"
            echo $i
            return 0
        end
        set i (math $i + 1)
    end
    return 1
end

function _modern_reminder_emit --argument-names cmd
    test -n "$MODERN_REMINDER"; or return
    contains -- $cmd $_modern_reminder_seen; and return
    set -l idx (_modern_reminder_lookup $cmd); or return
    set -l modern $_modern_reminder_modern[$idx]
    command -q $modern; or return
    set -l glyph $_modern_reminder_glyphs[$idx]
    set -l sample $_modern_reminder_samples[$idx]
    set -l prefix (printf '%b' $glyph)" $modern is a modern alternative to $cmd."
    if test -n "$sample"
        set prefix "$prefix $sample"
    end
    set_color yellow
    echo $prefix
    set_color normal
    set -g _modern_reminder_seen $_modern_reminder_seen $cmd
end

function _modern_reminder_scan --argument-names cmdline
    test -n "$MODERN_REMINDER"; or return
    # Replace pipe / semicolon / and-or / redirection bytes with spaces so
    # `string split` yields per-token boundaries. Backslash is intentionally
    # left untouched — we strip a leading '\' from each token below.
    set -l flat (string replace -ra '[|;&<>]' ' ' -- $cmdline)
    for tok in (string split --no-empty -- ' ' $flat)
        # Strip leading backslash (`\tail`) and dirname (`/usr/bin/tail`).
        set -l base (string replace -r '^\\\\' '' -- $tok)
        set base (string replace -r '^.*/' '' -- $base)
        if _modern_reminder_lookup $base >/dev/null
            _modern_reminder_emit $base
            return
        end
    end
end

# Hook bottom-guard: tests source this file with MODERN_REMINDER_TEST=1
# to load the function defs without registering the event handler.
test -n "$MODERN_REMINDER_TEST"; and return

function _modern_reminder_preexec --on-event fish_preexec
    _modern_reminder_scan $argv[1]
end

set -gx MODERN_REMINDER 1
