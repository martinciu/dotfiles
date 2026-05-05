-- Disable LSP auto-attach globally. Mason-installed servers stay on disk
-- so opt-in via :LspOn / vim.lsp.enable() is instant — they just don't
-- auto-attach on FileType events.
--
-- Why off by default: first-attach for any LSP is synchronous-feeling
-- (3-6s+ for jsonls on lazy-lock.json, ruby-lsp on first .rb in a Rails
-- project, marksman on a markdown-heavy repo, etc.), and dotfiles-style
-- editing rarely needs gd/hover/rename. Per-session opt-in via :LspOn
-- (see lua/config/keymaps.lua) covers the cases where LSP earns its
-- weight. Pairs with the VimLeavePre autocmd in lua/config/autocmds.lua
-- which force-drains LSP clients on exit.
local servers = {
  "lua_ls", "jsonls", "marksman", "vtsls", "ts_ls",
  "tailwindcss", "yamlls", "eslint", "ruby_lsp", "rubocop",
}

local opts = { servers = {} }
for _, name in ipairs(servers) do
  opts.servers[name] = { enabled = false, mason = false }
end

return {
  { "neovim/nvim-lspconfig", opts = opts },
}
