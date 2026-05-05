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

-- Force-stop all LSP clients before nvim exits so child processes and their
-- pipes drain deterministically. Without this, nvim's main shutdown can race
-- the LSP teardown — leaving leaked libuv handles (visible in
-- ~/.local/state/nvim/nvim.log as a uv_print_active_handles dump), a
-- non-zero exit code, and stale swap files from the unclean exit.
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local clients = vim.lsp.get_clients()
    if #clients == 0 then return end
    vim.lsp.stop_client(clients, true)
    vim.wait(500, function() return #vim.lsp.get_clients() == 0 end, 10)
  end,
})
