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

M.enable_scroll()

return M
