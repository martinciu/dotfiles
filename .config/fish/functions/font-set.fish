function font-set --description 'Switch Ghostty font (and optionally size)'
    set -l name $argv[1]
    set -l size $argv[2]
    switch $name
        case jetbrains fira cascadia monaspace iosevka \
             hack meslo sauce ubuntu inconsolata
            # OK
        case '*'
            echo "Usage: font-set <name> [<size>]" >&2
            echo "  name: jetbrains|fira|cascadia|monaspace|iosevka|hack|meslo|sauce|ubuntu|inconsolata" >&2
            echo "  size: positive number; omit to keep current size" >&2
            return 1
    end

    # Optional size: positive integer or decimal (Ghostty accepts e.g. 13.5).
    if set -q argv[2]
        if not string match -qr '^[0-9]+(\.[0-9]+)?$' -- $size
            echo "font-set: <size> must be a positive number, got: $size" >&2
            return 1
        end
        echo "font-size = $size" >~/.config/ghostty/font-size.ghostty
    end

    # Flip symlink. -sfn replaces the link atomically.
    ln -sfn font-$name.ghostty ~/.config/ghostty/font.ghostty

    # Live reload. Swallowed silently because ghostty may not be running.
    ghostty +reload 2>/dev/null

    if set -q argv[2]
        echo "font → $name (size $size)"
    else
        echo "font → $name"
    end
end
