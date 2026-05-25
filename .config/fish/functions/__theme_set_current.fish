function __theme_set_current --description 'Active theme name from the current.tmux symlink'
    set -l link ~/.config/themes/current.tmux
    test -L "$link"; or return 0
    string replace -r '\.tmux$' '' (readlink "$link")
end
