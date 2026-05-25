function __font_set_current --description 'Active font family name from the font.ghostty symlink'
    set -l link ~/.config/ghostty/font.ghostty
    test -L "$link"; or return 0
    string replace -r '^font-' '' (string replace -r '\.ghostty$' '' (readlink "$link"))
end
