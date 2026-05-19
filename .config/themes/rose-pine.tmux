# Rose Pine Main palette (rosepinetheme.com) — same role keys as
# solarized.tmux / mocha.tmux / dracula.tmux / gruvbox.tmux /
# tokyo-night.tmux / nord.tmux, Rose Pine hex.
# Designed for light-on-accent chip text — diverges from
# Mocha/Dracula/Gruvbox/Tokyo-Night's dark-on-accent and aligns with
# Solarized/Nord's light-on-saturated. Reason: pine #31748f
# (canonical Rose Pine "blue") at L≈37% is too dark for legible
# dark-on-accent text; light text resolves it.
# Rose Pine has no canonical green and no canonical orange.
# accent_green collapses to foam (cyan stand-in); accent_orange and
# accent_red collapse to love (single canonical pink). The in-palette
# collisions are faithful to the theme's six-accent spec; no current
# tmux pin uses both halves of either pair simultaneously.
# Rose (#ebbcba) lands on accent_magenta + starship pastel_rose only —
# its prominent UI slot is the prompt, not a tmux chip.

# Bases
set -g @color_bar_bg          "#191724"
set -g @color_deep_bg         "#1f1d2e"
set -g @color_default_fg      "#e0def4"
set -g @color_muted_fg        "#6e6a86"
# light_fg is light (#e0def4 = text) — chip-text inversion for Rose
# Pine's pine-driven session chip. Nord/Solarized pattern.
set -g @color_light_fg        "#e0def4"

# Accents
set -g @color_accent_yellow   "#f6c177"
set -g @color_accent_orange   "#eb6f92"
set -g @color_accent_red      "#eb6f92"
set -g @color_accent_magenta  "#ebbcba"
set -g @color_accent_violet   "#c4a7e7"
set -g @color_accent_blue     "#31748f"
set -g @color_accent_cyan     "#9ccfd8"
set -g @color_accent_green    "#9ccfd8"

# Derived chip values — light-on-accent inversion; foam/love hexes
# read as ins/del markers against the yellow chip.
set -g @color_chip_main_ins_fg "#9ccfd8"
set -g @color_chip_main_del_fg "#eb6f92"
set -g @color_chip_main_neutral_fg "#e0def4"
set -g @color_chip_wt_ins_fg   "#9ccfd8"
set -g @color_chip_wt_del_fg   "#eb6f92"
