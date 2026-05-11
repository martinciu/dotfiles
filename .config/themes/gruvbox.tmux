# Gruvbox Dark Medium palette — same role keys as solarized.tmux /
# mocha.tmux / dracula.tmux, Gruvbox hex. Designed for dark-on-accent
# chip text (Mocha/Dracula pattern). Gruvbox has one canonical purple,
# so @color_accent_magenta and @color_accent_violet resolve to the same
# hex (#b16286) — faithful to the palette; no current tmux pin
# distinguishes the two roles.

# Bases
set -g @color_bar_bg          "#3c3836"
set -g @color_deep_bg         "#282828"
set -g @color_default_fg      "#ebdbb2"
set -g @color_muted_fg        "#928374"
# light_fg here is dark (#282828 = Gruvbox bg0) — chip-text inversion
# for Gruvbox's saturated accents (yellow/orange/purple/blue/green).
set -g @color_light_fg        "#282828"

# Accents
set -g @color_accent_yellow   "#d79921"
set -g @color_accent_orange   "#d65d0e"
set -g @color_accent_red      "#cc241d"
set -g @color_accent_magenta  "#b16286"
set -g @color_accent_violet   "#b16286"
set -g @color_accent_blue     "#458588"
set -g @color_accent_cyan     "#689d6a"
set -g @color_accent_green    "#98971a"

# Derived chip values (theme-tuned, not 1:1)
set -g @color_chip_main_ins_fg "#b8bb26"
set -g @color_chip_main_del_fg "#fb4934"
set -g @color_chip_main_neutral_fg "#ebdbb2"
set -g @color_chip_wt_ins_fg   "#3a4a14"
set -g @color_chip_wt_del_fg   "#5a1414"
