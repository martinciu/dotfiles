# atuin — Ctrl-R history picker with exit-status markers and scope cycling.
# Loads after 40-plugins.fish (which runs `fzf --fish | source` and grabs
# Ctrl-R for fzf's history widget). atuin's init rebinds Ctrl-R to its
# own picker; fzf's Ctrl-T / Ctrl-V / Ctrl-S / Ctrl-Alt-F widgets are
# unaffected. Up arrow is also bound to atuin's session-scoped picker.
# Config in .config/atuin/config.toml; history at ~/.local/share/atuin/.
if command -q atuin
    atuin init fish | source
end
