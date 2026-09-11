# Kanagawa Wave palette — same role keys as solarized.tmux /
# everforest.tmux, Kanagawa hex. Designed for dark-on-accent chip text
# (Gruvbox/Mocha pattern). Accents are Ghostty's ANSI-normal set
# (palette 1-6) — the muted half — matching what gruvbox.tmux and
# tokyo-night.tmux do, and what fzf/atuin/fx render via ANSI refs.
# Unlike Everforest, Kanagawa has two distinct purples, so
# @color_accent_magenta and @color_accent_violet differ.

# Bases
# bar_bg is sumiInk3 — the same hex Ghostty paints as the terminal
# background, so the status bar sits flush with the pane instead of
# reading as a band. That is the dracula / mocha / nord / tokyo-night /
# rose-pine / everforest school; solarized and gruvbox take the other
# one. deep_bg therefore drops to sumiInk0, one step under the bar, so
# copy-mode selection and the prefix-: command prompt still read as a
# distinct field against a flush bar.
set -g @color_bar_bg          "#1f1f28"
set -g @color_deep_bg         "#16161d"
set -g @color_default_fg      "#dcd7ba"
set -g @color_muted_fg        "#727169"
# light_fg here is dark (#1f1f28 = sumiInk3) — chip-text inversion.
# Measured: chips render bold, so 3.0 is the applicable WCAG AA
# threshold. Light text on fujiWhite clears 3.0 on exactly one of the
# sixteen candidate accents; dark text clears on all sixteen, worst
# case autumnRed at 3.22. Equal to bar_bg, as in dracula / rose-pine /
# tokyo-night / everforest, so every chip carries the same dark text.
set -g @color_light_fg        "#1f1f28"

# Accents — Ghostty "Kanagawa Wave" palette 1-6, plus orange and
# magenta, which Kanagawa places outside the ANSI range.
set -g @color_accent_yellow   "#c0a36e"
set -g @color_accent_orange   "#ffa066"
set -g @color_accent_red      "#c34043"
set -g @color_accent_magenta  "#d27e99"
set -g @color_accent_violet   "#957fb8"
set -g @color_accent_blue     "#7e9cd8"
set -g @color_accent_cyan     "#6a9589"
set -g @color_accent_green    "#76946a"

# Derived chip values (theme-tuned, not 1:1). The wt_* pair is dark text
# on an accent-coloured chip; both reuse the delta emph grounds so the
# diff and status surfaces agree. Those grounds are winterGreen/winterRed
# blended 30% toward autumnGreen/autumnRed, which lands within 0.006
# relative luminance of Everforest's hand-derived pair.
set -g @color_chip_main_ins_fg "#76946a"
set -g @color_chip_main_del_fg "#c34043"
set -g @color_chip_main_neutral_fg "#dcd7ba"
set -g @color_chip_wt_ins_fg   "#42503c"
set -g @color_chip_wt_del_fg   "#692c32"
