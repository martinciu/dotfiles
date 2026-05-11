function font-set --description 'Switch Ghostty font (and optionally weight, size)'
    set -l name $argv[1]
    set -l weight $argv[2]
    set -l size $argv[3]
    switch $name
        case jetbrains fira cascadia monaspace iosevka \
             hack meslo sauce ubuntu inconsolata
            # OK
        case '*'
            echo "Usage: font-set <name> [<weight>] [<size>]" >&2
            echo "  name:   jetbrains|fira|cascadia|monaspace|iosevka|hack|meslo|sauce|ubuntu|inconsolata" >&2
            echo "  weight: per-font style name (Tab to discover); omit to keep current weight" >&2
            echo "  size:   positive number; omit to keep current size" >&2
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

    # Live reload. Swallowed silently because ghostty may not be running.
    ghostty +reload 2>/dev/null

    set -l msg "font → $name"
    set -q argv[2]; and test -n "$weight"; and set msg "$msg (weight $weight)"
    set -q argv[3]; and test -n "$size";   and set msg "$msg (size $size)"
    echo $msg
end
