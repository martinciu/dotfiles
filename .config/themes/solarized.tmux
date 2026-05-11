# Solarized Dark palette — semantic role → hex. Sourced by tmux.conf via
# ~/.config/themes/current.tmux symlink. Helper scripts read these via
# `tmux show-option -gv @color_<role>`.

# Bases
set -g @color_bar_bg          "#073642"
set -g @color_deep_bg         "#002b36"
set -g @color_default_fg      "#839496"
set -g @color_muted_fg        "#586e75"
set -g @color_light_fg        "#fdf6e3"

# Accents
set -g @color_accent_yellow   "#b58900"
set -g @color_accent_orange   "#cb4b16"
set -g @color_accent_red      "#dc322f"
set -g @color_accent_magenta  "#d33682"
set -g @color_accent_violet   "#6c71c4"
set -g @color_accent_blue     "#268bd2"
set -g @color_accent_cyan     "#2aa198"
set -g @color_accent_green    "#859900"

# Derived chip values (theme-tuned, not 1:1)
set -g @color_chip_main_ins_fg "#b8d65c"
set -g @color_chip_main_del_fg "#ff9b96"
set -g @color_chip_main_neutral_fg "#eee8d5"
set -g @color_chip_wt_ins_fg   "#3a5400"
set -g @color_chip_wt_del_fg   "#7a1116"
