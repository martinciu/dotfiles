function font-set --description 'Switch Ghostty font; bare = show current, --stats = usage report'
    set -l usage "Usage: font-set <name> [<weight>] [<size>]
  name:   jetbrains|fira|cascadia|monaspace|iosevka|hack|meslo|sauce|ubuntu|inconsolata
          departure|bigblue|0xproto|3270|hurmit|monofur|dyslexic
  weight: per-font style name (Tab to discover); omit to keep current weight
  size:   positive number; omit to keep current size
  font-set                     show current font + when set
  font-set --stats [--all]     per-font usage report"

    if contains -- -h $argv; or contains -- --help $argv
        echo $usage
        return 0
    end

    if contains -- --stats $argv
        set -l all 0
        contains -- --all $argv; and set all 1
        set -l cur (__font_set_current)
        __theme_font_history font-set (__font_set_names) \
            | __theme_font_stats_report FONT "$cur" $all (__font_set_names)
        return 0
    end

    set -l name $argv[1]
    set -l weight $argv[2]
    set -l size $argv[3]

    if test -z "$name"
        __font_set_readout
        return 0
    end

    if not contains -- $name (__font_set_names)
        echo $usage >&2
        return 1
    end

    # Optional weight: must be one of the styles the picked font advertises.
    if set -q argv[2]; and test -n "$weight"
        set -l valid (__font_set_weights_for $name)
        if not contains -- $weight $valid
            echo "font-set: <weight> not supported by $name: $weight" >&2
            echo "  valid: $valid" >&2
            return 1
        end
        echo "font-style = $weight" >~/.config/ghostty/font-weight.ghostty
    end

    # Optional size: positive integer or decimal (Ghostty accepts e.g. 13.5).
    if set -q argv[3]; and test -n "$size"
        if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- $size
            echo "font-set: <size> must be a positive number, got: $size" >&2
            return 1
        end
        echo "font-size = $size" >~/.config/ghostty/font-size.ghostty
    end

    # Flip family symlink. -sfn replaces the link atomically.
    ln -sfn font-$name.ghostty ~/.config/ghostty/font.ghostty

    set -l msg "font → $name"
    set -q argv[2]; and test -n "$weight"; and set msg "$msg (weight $weight)"
    set -q argv[3]; and test -n "$size";   and set msg "$msg (size $size)"
    echo $msg

    # Fire the ghostty config reload (cmd+ctrl+shift+r via System Events when
    # Ghostty is frontmost). Discard the helper's info line — the reload still
    # happens as a side effect; the printed "how to" was just noise.
    __ghostty_reload >/dev/null
end
