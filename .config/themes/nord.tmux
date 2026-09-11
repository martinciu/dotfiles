# Nord palette (Sven Greb) — same role keys as solarized.tmux /
# mocha.tmux / dracula.tmux / gruvbox.tmux / tokyo-night.tmux, Nord hex.
# Dark-on-accent chip text, matching 8 of the 11 themes.
#
# This used to be light-on-accent (nord6 #eceff4), on the argument that
# the Frost-blue session chip (#5e81ac) reads flat with dark text. That
# holds for blue alone — but Nord's Aurora accents are far lighter, and
# light text on them failed badly (#394):
#
#   chip (accent)            light #eceff4   dark #2e3440
#   session      (#5e81ac)       3.50           3.10
#   active win   (#a3be8c)       1.77  ❌        6.13
#   PR pin       (#d08770)       2.47  ❌        4.39
#   cost         (#bf616a)       3.55           3.05
#   main branch  (#b48ead)       2.46  ❌        4.41
#
# Chips render bold, so 3.0 is the applicable WCAG AA threshold. Light
# text cleared it on two of five; dark clears it on all five, at the cost
# of 0.4 on the session chip and 0.5 on the cost chip. nord0 is also the
# darkest tone Nord defines — nothing in-palette improves the two
# mid-accent worst cases further.
# Nord has one canonical purple (nord15), so @color_accent_magenta and
# @color_accent_violet resolve to the same hex (#b48ead) — faithful to
# the palette; no current tmux pin distinguishes the two roles.

# Bases
set -g @color_bar_bg          "#2e3440"
set -g @color_deep_bg         "#3b4252"
set -g @color_default_fg      "#d8dee9"
set -g @color_muted_fg        "#4c566a"
# Chip text on every accent-backed pin. nord0 — same tone as bar_bg,
# which is the shape the other dark-on-accent themes use.
set -g @color_light_fg        "#2e3440"

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
