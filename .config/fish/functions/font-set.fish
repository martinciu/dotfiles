function font-set --description 'Switch Ghostty font between installed Nerd Fonts'
    set -l name $argv[1]
    switch $name
        case jetbrains fira cascadia monaspace iosevka \
             hack meslo sauce ubuntu inconsolata
            # OK
        case '*'
            echo "Usage: font-set <jetbrains|fira|cascadia|monaspace|iosevka|hack|meslo|sauce|ubuntu|inconsolata>" >&2
            return 1
    end

    # Flip symlink. -sfn replaces the link atomically.
    ln -sfn font-$name.ghostty ~/.config/ghostty/font.ghostty

    # Live reload. Swallowed silently because ghostty may not be running.
    ghostty +reload 2>/dev/null

    echo "font → $name"
end
