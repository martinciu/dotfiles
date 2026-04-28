-- Loaded automatically on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Polish keyboard reserves Alt for diacritics (ą/ć/ę/ł/ń/ó/ś/ź/ż).
-- LazyVim defaults bind <A-j>/<A-k> to move-line; remove them.
-- pcall guards against load-order edge cases where the map isn't set yet.
local del = vim.keymap.del
pcall(del, { "n", "i", "v" }, "<A-j>")
pcall(del, { "n", "i", "v" }, "<A-k>")
