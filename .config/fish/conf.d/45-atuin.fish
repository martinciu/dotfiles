# atuin — Ctrl-R history picker with exit-status markers and scope cycling.
# Loads after 40-plugins.fish (which runs `fzf --fish | source` and grabs
# Ctrl-R for fzf's history widget). atuin's init rebinds Ctrl-R to its
# own picker; fzf's Ctrl-T / Ctrl-V / Ctrl-S / Ctrl-Alt-F widgets are
# unaffected. `--disable-up-arrow` leaves the Up key on fish's native
# history search (previous command), which feels more natural than
# atuin's session-scoped mini-picker for fast re-runs.
# Config in .config/atuin/config.toml; history at ~/.local/share/atuin/.
if command -q atuin
    atuin init fish --disable-up-arrow | source
end
