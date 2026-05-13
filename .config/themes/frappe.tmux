# Catppuccin Frappé palette — same role keys as solarized.tmux, Frappé hex.
# Designed for dark-on-pastel chip text (like Mocha).

# Bases
set -g @color_bar_bg          "#303446"
set -g @color_deep_bg         "#232634"
set -g @color_default_fg      "#c6d0f5"
set -g @color_muted_fg        "#737994"
# light_fg here is dark (#232634 crust) — Frappé's chip-text inversion: pastel
# chip bgs (mauve/peach/blue/green/yellow) read better with dark text than
# light. The role name is shared with Solarized, but the value is theme-tuned.
set -g @color_light_fg        "#232634"

# Accents
set -g @color_accent_yellow   "#e5c890"
set -g @color_accent_orange   "#ef9f76"
set -g @color_accent_red      "#e78284"
set -g @color_accent_magenta  "#f4b8e4"
set -g @color_accent_violet   "#ca9ee6"
set -g @color_accent_blue     "#8caaee"
set -g @color_accent_cyan     "#81c8be"
set -g @color_accent_green    "#a6d189"

# Derived chip values (theme-tuned, not 1:1)
set -g @color_chip_main_ins_fg "#a6d189"
set -g @color_chip_main_del_fg "#ea999c"
set -g @color_chip_main_neutral_fg "#b5bfe2"
set -g @color_chip_wt_ins_fg   "#40620d"
set -g @color_chip_wt_del_fg   "#7a1f2a"
