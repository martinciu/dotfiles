-- nvimpager loads THIS file as its config — NOT ~/.config/nvim. To get the
-- same smooth scroll as nvim, reuse the snacks.nvim that nvim's lazy already
-- installed. nvimpager rewrites neovim's stdpath(), so the path is hardcoded
-- to nvim's lazy dir rather than derived via stdpath("data").
local M = {}

-- Enable snacks.scroll by reusing nvim's lazy-installed copy. Returns true if
-- snacks was found and enabled, false if it is absent (fresh machine before
-- nvim's first launch) — paging still works, just without animation.
-- snacks_path is injectable so the smoke test can drive both branches.
function M.enable_scroll(snacks_path)
  snacks_path = snacks_path or vim.fn.expand("~/.local/share/nvim/lazy/snacks.nvim")
  if not (vim.uv or vim.loop).fs_stat(snacks_path) then
    return false
  end
  vim.opt.runtimepath:append(snacks_path)
  require("snacks").setup({ scroll = { enabled = true } })
  return true
end

-- Apply the active nvim colorscheme so paged output matches the theme-set
-- stack. Reuses nvim's resolver (config.theme) as the single source of truth,
-- then globs nvim's lazy plugin dirs onto runtimepath so :colorscheme can find
-- the resolved scheme. No setup() — palette only. lazy_root is injectable so
-- the smoke test can drive the present/absent branches. Returns true if a
-- colorscheme was applied, false on a fresh machine (no lazy dir) or if nvim's
-- config has moved (config.theme unrequireable) — paging still works either way.
function M.apply_theme(lazy_root)
  lazy_root = lazy_root or vim.fn.expand("~/.local/share/nvim/lazy")
  local nvim_lua = vim.fn.expand("~/.config/nvim/lua")
  package.path = nvim_lua .. "/?.lua;" .. nvim_lua .. "/?/init.lua;" .. package.path
  local ok, theme = pcall(require, "config.theme")
  if not ok then
    return false
  end
  local dirs = vim.fn.glob(lazy_root .. "/*", false, true)
  if #dirs == 0 then
    return false
  end
  for _, dir in ipairs(dirs) do
    vim.opt.runtimepath:append(dir)
  end
  -- nvimpager cat-mode emits 24-bit SGR only when termguicolors is on; headless
  -- nvim defaults it off. Schemes like solarized8 define gui colors but no cterm
  -- fallback and don't self-enable it, so without this the default theme pages
  -- with no color at all. Forcing it on renders every theme's true palette.
  vim.o.termguicolors = true
  return pcall(vim.cmd.colorscheme, theme.current())
end

M.enable_scroll()
M.apply_theme()

return M
