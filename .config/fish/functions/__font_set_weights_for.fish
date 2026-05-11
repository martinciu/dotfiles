function __font_set_weights_for --argument-names name \
        --description 'Style names Ghostty accepts as font-style for a given font-set short name'
    # One weight per line — callers iterate via command substitution and
    # `contains` expects list elements, not a single space-joined string.
    switch $name
        case jetbrains
            printf '%s\n' Thin ExtraLight Light Regular Medium SemiBold Bold ExtraBold
        case fira
            # FiraCode advertises abbreviated style names.
            printf '%s\n' Light Reg Med Ret SemBd Bold
        case cascadia
            printf '%s\n' ExtraLight Light SemiLight Regular SemiBold Bold
        case monaspace
            printf '%s\n' Light Regular Medium Bold
        case iosevka
            printf '%s\n' Thin ExtraLight Light Regular Medium SemiBold Bold ExtraBold Heavy
        case sauce
            printf '%s\n' ExtraLight Light Regular Medium SemiBold Bold Black
        case hack meslo ubuntu inconsolata
            printf '%s\n' Regular Bold
    end
end
