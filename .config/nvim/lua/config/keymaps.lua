-- Loaded automatically on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Polish keyboard reserves Alt for diacritics (ą/ć/ę/ł/ń/ó/ś/ź/ż).
-- LazyVim defaults bind <A-j>/<A-k> to move-line; remove them.
-- pcall guards against load-order edge cases where the map isn't set yet.
local del = vim.keymap.del
pcall(del, { "n", "i", "v" }, "<A-j>")
pcall(del, { "n", "i", "v" }, "<A-k>")

-- Opt-in LSP per session. Usage: `:LspOn vtsls`.
-- Sugar for vim.lsp.enable() — registers the server's FileType autocmd
-- so every matching buffer in this session auto-attaches (existing
-- buffers included). For projects where you want it always on, drop
-- a .nvim.lua at the repo root with vim.lsp.enable({...}); requires
-- vim.o.exrc = true (not currently set).
vim.api.nvim_create_user_command("LspOn", function(args)
  vim.lsp.enable(args.args)
end, {
  nargs = 1,
  desc = "Enable an LSP server for this session",
})
