# Dracula palette — same role keys as solarized.tmux / mocha.tmux, Dracula hex.
# Designed for dark-on-pastel chip text (Mocha pattern). Dracula has no pure
# blue accent — @color_accent_blue intentionally reuses the comment hex,
# which collides with @color_muted_fg. Faithful to Dracula; @color_accent_blue
# is unused by current tmux pins.

# Bases
set -g @color_bar_bg          "#282a36"
set -g @color_deep_bg         "#21222c"
set -g @color_default_fg      "#f8f8f2"
set -g @color_muted_fg        "#6272a4"
# light_fg here is dark (#282a36 bg) — chip-text inversion for Dracula's
# saturated-but-readable accents (pink/purple/cyan/orange/yellow).
set -g @color_light_fg        "#282a36"

# Accents
set -g @color_accent_yellow   "#f1fa8c"
set -g @color_accent_orange   "#ffb86c"
set -g @color_accent_red      "#ff5555"
set -g @color_accent_magenta  "#ff79c6"
set -g @color_accent_violet   "#bd93f9"
set -g @color_accent_blue     "#6272a4"
set -g @color_accent_cyan     "#8be9fd"
set -g @color_accent_green    "#50fa7b"

# Derived chip values (theme-tuned, not 1:1)
set -g @color_chip_main_ins_fg "#50fa7b"
set -g @color_chip_main_del_fg "#ff5555"
set -g @color_chip_main_neutral_fg "#f8f8f2"
set -g @color_chip_wt_ins_fg   "#1e3a14"
set -g @color_chip_wt_del_fg   "#5a1414"
