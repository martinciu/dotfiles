# Nord palette (Sven Greb) — same role keys as solarized.tmux /
# mocha.tmux / dracula.tmux / gruvbox.tmux / tokyo-night.tmux, Nord hex.
# Designed for light-on-accent chip text — diverges from
# Mocha/Dracula/Gruvbox/Tokyo-Night's dark-on-accent and aligns with
# Solarized's light-on-saturated. Reason: Nord's Frost-blue session
# chip (#5e81ac) reads flat with dark text; light text resolves it.
# Nord has one canonical purple (nord15), so @color_accent_magenta and
# @color_accent_violet resolve to the same hex (#b48ead) — faithful to
# the palette; no current tmux pin distinguishes the two roles.

# Bases
set -g @color_bar_bg          "#2e3440"
set -g @color_deep_bg         "#3b4252"
set -g @color_default_fg      "#d8dee9"
set -g @color_muted_fg        "#4c566a"
# light_fg here is light (#eceff4 = nord6) — chip-text inversion for
# Nord's mid-range accent saturations. Solarized pattern.
set -g @color_light_fg        "#eceff4"

# Accents
set -g @color_accent_yellow   "#ebcb8b"
set -g @color_accent_orange   "#d08770"
set -g @color_accent_red      "#bf616a"
set -g @color_accent_magenta  "#b48ead"
set -g @color_accent_violet   "#b48ead"
set -g @color_accent_blue     "#5e81ac"
set -g @color_accent_cyan     "#88c0d0"
set -g @color_accent_green    "#a3be8c"

# Derived chip values — full Aurora saturation against the yellow chip,
# overriding Gruvbox/Tokyo-Night's very-dark tints which assumed
# dark-on-accent chip text.
set -g @color_chip_main_ins_fg "#a3be8c"
set -g @color_chip_main_del_fg "#bf616a"
set -g @color_chip_main_neutral_fg "#d8dee9"
set -g @color_chip_wt_ins_fg   "#a3be8c"
set -g @color_chip_wt_del_fg   "#bf616a"
