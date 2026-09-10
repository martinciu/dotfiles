# Everforest Dark Medium palette — same role keys as solarized.tmux /
# gruvbox.tmux, Everforest hex. Designed for dark-on-accent chip text
# (Gruvbox/Mocha pattern). Everforest has one canonical purple, so
# @color_accent_magenta and @color_accent_violet resolve to the same
# hex (#d699b6) — faithful to the palette; no current tmux pin
# distinguishes the two roles.

# Bases
set -g @color_bar_bg          "#343f44"
set -g @color_deep_bg         "#2d353b"
set -g @color_default_fg      "#d3c6aa"
set -g @color_muted_fg        "#859289"
# light_fg here is dark (#2d353b = Everforest bg0) — chip-text inversion.
# Everforest's accents are light and low-saturation, so light-on-accent
# would be illegible.
set -g @color_light_fg        "#2d353b"

# Accents
set -g @color_accent_yellow   "#dbbc7f"
set -g @color_accent_orange   "#e69875"
set -g @color_accent_red      "#e67e80"
set -g @color_accent_magenta  "#d699b6"
set -g @color_accent_violet   "#d699b6"
set -g @color_accent_blue     "#7fbbb3"
set -g @color_accent_cyan     "#83c092"
set -g @color_accent_green    "#a7c080"

# Derived chip values (theme-tuned, not 1:1). The wt_* pair is dark text
# on an accent-coloured chip; both reuse the delta emph grounds so the
# diff and status surfaces agree.
set -g @color_chip_main_ins_fg "#a7c080"
set -g @color_chip_main_del_fg "#e67e80"
set -g @color_chip_main_neutral_fg "#d3c6aa"
set -g @color_chip_wt_ins_fg   "#3d5233"
set -g @color_chip_wt_del_fg   "#5e2f33"
