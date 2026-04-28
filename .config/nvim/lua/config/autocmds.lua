-- Loaded automatically on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add custom autocommands here.

-- LazyVim's `lazyvim_wrap_spell` group sets spell=true for text-y filetypes,
-- overriding the global `spell = false` from options.lua. Re-disable on the
-- same FileType events; runs after LazyVim's because it registers later.
local spell_filetypes = { "text", "plaintex", "typst", "gitcommit", "markdown" }
vim.api.nvim_create_autocmd("FileType", {
  pattern = spell_filetypes,
  callback = function() vim.opt_local.spell = false end,
})
if vim.tbl_contains(spell_filetypes, vim.bo.filetype) then
  vim.opt_local.spell = false
end
