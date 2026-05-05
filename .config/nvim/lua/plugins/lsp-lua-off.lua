-- Disable lua_ls entirely. LazyVim core declares it in its default server set
-- (lazy/LazyVim/lua/lazyvim/plugins/lsp/init.lua), so :MasonUninstall alone
-- doesn't stick — mason-lspconfig auto-reinstalls on next startup.
--
-- We don't enable LazyVim's lang.lua extra, so lazydev's workspace tuning
-- isn't wired up. Without it, lua_ls scans the cwd as workspace and can
-- wander into ~/.local/share/nvim/lazy/ (~190 MB of plugin Lua) when opening
-- Lua files outside an nvim config root — the slowness root cause.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = { enabled = false, mason = false },
      },
    },
  },
}
