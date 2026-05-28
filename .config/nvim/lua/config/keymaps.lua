-- Loaded automatically on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- Opt-in LSP per session. Usage: `:LspOn vtsls`.
-- Sugar for vim.lsp.enable() — registers the server's FileType autocmd
-- so every matching buffer in this session auto-attaches (existing
-- buffers included). For projects where you want it always on, drop
-- a .nvim.lua at the repo root with vim.lsp.enable({...}); requires
-- vim.o.exrc = true (not currently set).

-- Per-server cmd overrides applied at opt-in time. ruby_lsp and rubocop must
-- run via the mise shim, not lspconfig's defaults (`ruby-lsp`, `rubocop --lsp`)
-- which resolve to Mason's binaries first, since mason.nvim prepends its bin to
-- nvim's PATH. Mason's wrappers carry a frozen shebang to a removed rbenv ruby
-- after the rbenv->mise migration, so they die with "bad interpreter". The
-- shims re-resolve ruby per project and run inside the project bundle -- the
-- same binary the per-project .nvim.lua files use.
-- Note: don't :LspOn both -- ruby_lsp already runs RuboCop as an addon, so
-- standalone rubocop on top doubles diagnostics. Use rubocop alone only when
-- you want lint without full ruby-lsp.
local lsp_cmd_overrides = {
  ruby_lsp = { vim.fn.expand("~/.local/share/mise/shims/ruby-lsp") },
  rubocop = { vim.fn.expand("~/.local/share/mise/shims/rubocop"), "--lsp" },
}

vim.api.nvim_create_user_command("LspOn", function(args)
  local name = args.args
  local override = lsp_cmd_overrides[name]
  if override then
    vim.lsp.config(name, { cmd = override })
  end
  vim.lsp.enable(name)
end, {
  nargs = 1,
  desc = "Enable an LSP server for this session",
})
