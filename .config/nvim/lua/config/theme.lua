-- Theme resolver: reads ~/.config/themes/current.tmux symlink target to
-- decide which colorscheme nvim should load at startup. Returns one of:
--   "solarized"        (default, when symlink missing or unreadable)
--   "catppuccin-mocha"
--   "dracula"
local M = {}

function M.current()
  local link = vim.uv.fs_readlink(vim.fn.expand("~/.config/themes/current.tmux"))
  if link then
    if link:match("mocha") then
      return "catppuccin-mocha"
    elseif link:match("dracula") then
      return "dracula"
    end
  end
  return "solarized"
end

return M
