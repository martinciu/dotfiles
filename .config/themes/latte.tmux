# Catppuccin Latte palette — same role keys as mocha.tmux, Latte hex.
# First light theme: bar bg is mantle (#e6e9ef), not a dark surface.
# Designed for light-on-saturated chip text — Latte's accents are
# saturated enough to carry light text (cf. Mocha's pastel
# accents + dark text).

# Bases
set -g @color_bar_bg          "#e6e9ef"
set -g @color_deep_bg         "#dce0e8"
set -g @color_default_fg      "#4c4f69"
set -g @color_muted_fg        "#8c8fa1"
# Chip-text inversion: light on saturated. Same role name as
# Solarized/Mocha, theme-tuned value (#eff1f5 = base).
set -g @color_light_fg        "#eff1f5"

# Accents — Catppuccin Latte spec
set -g @color_accent_yellow   "#df8e1d"
set -g @color_accent_orange   "#fe640b"
set -g @color_accent_red      "#d20f39"
set -g @color_accent_magenta  "#ea76cb"
set -g @color_accent_violet   "#8839ef"
set -g @color_accent_blue     "#1e66f5"
set -g @color_accent_cyan     "#04a5e5"
set -g @color_accent_green    "#40a02b"

# Derived chip values — hand-derived for light-bar contrast.
# Main chip bg is mauve (#8839ef), wt chip bg is yellow (#df8e1d).
set -g @color_chip_main_ins_fg     "#a6e3a1"
set -g @color_chip_main_del_fg     "#eba0ac"
set -g @color_chip_main_neutral_fg "#cdd6f4"
set -g @color_chip_wt_ins_fg       "#40620d"
set -g @color_chip_wt_del_fg       "#7a1f2a"
