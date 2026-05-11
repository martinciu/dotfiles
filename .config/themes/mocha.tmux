# Catppuccin Mocha palette — same role keys as solarized.tmux, Mocha hex.
# Designed for dark-on-pastel chip text (Solarized uses light-on-saturated).

# Bases
set -g @color_bar_bg          "#1e1e2e"
set -g @color_deep_bg         "#11111b"
set -g @color_default_fg      "#cdd6f4"
set -g @color_muted_fg        "#6c7086"
# light_fg here is dark (#11111b crust) — Mocha's chip-text inversion: pastel
# chip bgs (mauve/peach/blue/green/yellow) read better with dark text than
# light. The role name is shared with Solarized, but the value is theme-tuned.
set -g @color_light_fg        "#11111b"

# Accents
set -g @color_accent_yellow   "#f9e2af"
set -g @color_accent_orange   "#fab387"
set -g @color_accent_red      "#f38ba8"
set -g @color_accent_magenta  "#f5c2e7"
set -g @color_accent_violet   "#cba6f7"
set -g @color_accent_blue     "#89b4fa"
set -g @color_accent_cyan     "#94e2d5"
set -g @color_accent_green    "#a6e3a1"

# Derived chip values (theme-tuned, not 1:1)
set -g @color_chip_main_ins_fg "#a6e3a1"
set -g @color_chip_main_del_fg "#eba0ac"
set -g @color_chip_main_neutral_fg "#bac2de"
set -g @color_chip_wt_ins_fg   "#40620d"
set -g @color_chip_wt_del_fg   "#7a1f2a"
