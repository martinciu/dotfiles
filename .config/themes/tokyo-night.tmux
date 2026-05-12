# Tokyo Night Storm palette — same role keys as solarized.tmux /
# mocha.tmux / dracula.tmux / gruvbox.tmux, Tokyo Night Storm hex.
# Designed for dark-on-accent chip text (Mocha/Dracula/Gruvbox pattern).
# Tokyo Night has one canonical purple, so @color_accent_magenta and
# @color_accent_violet resolve to the same hex (#bb9af7) — faithful to
# the palette; no current tmux pin distinguishes the two roles.

# Bases
set -g @color_bar_bg          "#24283b"
set -g @color_deep_bg         "#1a1b26"
set -g @color_default_fg      "#c0caf5"
set -g @color_muted_fg        "#565f89"
# light_fg here is dark (#24283b = Storm bg) — chip-text inversion
# for Tokyo Night's pastel-ish accents (blue/purple/cyan/green/yellow).
set -g @color_light_fg        "#24283b"

# Accents
set -g @color_accent_yellow   "#e0af68"
set -g @color_accent_orange   "#ff9e64"
set -g @color_accent_red      "#f7768e"
set -g @color_accent_magenta  "#bb9af7"
set -g @color_accent_violet   "#bb9af7"
set -g @color_accent_blue     "#7aa2f7"
set -g @color_accent_cyan     "#7dcfff"
set -g @color_accent_green    "#9ece6a"

# Derived chip values (theme-tuned, not 1:1)
set -g @color_chip_main_ins_fg "#9ece6a"
set -g @color_chip_main_del_fg "#f7768e"
set -g @color_chip_main_neutral_fg "#c0caf5"
set -g @color_chip_wt_ins_fg   "#3a4a14"
set -g @color_chip_wt_del_fg   "#5a1414"
