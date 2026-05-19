# Rose Pine Moon palette (rosepinetheme.com) — accessibility-tuned
# medium-dark variant (2.5 contrast ratio). Structurally identical to
# rose-pine.tmux: same role keys, same light-on-accent inversion.
# Moon-specific hex diffs: brighter pine (#3e8fb0 vs Main's #31748f),
# more terra-cotta rose (#ea9a97 vs Main's #ebbcba), shifted bases.

# Bases
set -g @color_bar_bg          "#232136"
set -g @color_deep_bg         "#2a273f"
set -g @color_default_fg      "#e0def4"
set -g @color_muted_fg        "#6e6a86"
set -g @color_light_fg        "#e0def4"

# Accents
set -g @color_accent_yellow   "#f6c177"
set -g @color_accent_orange   "#eb6f92"
set -g @color_accent_red      "#eb6f92"
set -g @color_accent_magenta  "#ea9a97"
set -g @color_accent_violet   "#c4a7e7"
set -g @color_accent_blue     "#3e8fb0"
set -g @color_accent_cyan     "#9ccfd8"
set -g @color_accent_green    "#9ccfd8"

# Derived chip values — light-on-accent inversion; foam/love hexes
# read as ins/del markers against the yellow chip.
set -g @color_chip_main_ins_fg "#9ccfd8"
set -g @color_chip_main_del_fg "#eb6f92"
set -g @color_chip_main_neutral_fg "#e0def4"
set -g @color_chip_wt_ins_fg   "#9ccfd8"
set -g @color_chip_wt_del_fg   "#eb6f92"
