-- Theme resolver: reads ~/.config/themes/current.tmux symlink target to
-- decide which colorscheme nvim should load at startup. Returns one of:
--   "solarized"        (default, when symlink missing or unreadable)
--   "catppuccin-mocha"
--   "catppuccin-frappe"
--   "dracula"
--   "gruvbox"
--   "tokyonight-storm"
local M = {}

function M.current()
  local link = vim.uv.fs_readlink(vim.fn.expand("~/.config/themes/current.tmux"))
  if link then
    if link:match("mocha") then
      return "catppuccin-mocha"
    elseif link:match("frappe") then
      return "catppuccin-frappe"
    elseif link:match("dracula") then
      return "dracula"
    elseif link:match("gruvbox") then
      return "gruvbox"
    elseif link:match("tokyo%-night") then
      return "tokyonight-storm"
    end
  end
  return "solarized"
end

return M
