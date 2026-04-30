-- Loaded automatically before lazy.nvim startup.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- This file mirrors the existing ~/.vimrc to keep both editors consistent.

local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.ruler = true
opt.showcmd = true
opt.wildmenu = true
opt.wildmode = "list:longest,full"
opt.belloff = "all" -- dotfiles convention: bells silenced everywhere

-- Search
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Indent
opt.autoindent = true
opt.smartindent = true
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2

-- Editing
opt.backspace = "indent,eol,start"
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.mouse = "a"
opt.clipboard = "unnamed"
opt.hidden = true
opt.spell = false

-- Persistent files (nvim uses XDG state by default; explicit for clarity)
opt.undofile = true

-- Color
opt.termguicolors = true
opt.background = "dark"

-- Never descend into worktree directories from built-in completion (`:e <Tab>`,
-- `:find`, netrw, wildmenu). Snacks pickers are handled separately in
-- lua/plugins/snacks.lua.
vim.opt.wildignore:append({ "*/.claude/worktrees/*" })

-- ─── Per-tmux-session RPC server ─────────────────────────────────────────
-- When launched inside tmux (and not as a child of another nvim), start a
-- server on a per-tmux-session socket so external tools can target this
-- nvim by tmux session name.
--
-- Used by ~/.config/tmux/bin/tmux-open-in-nvim (bound to <prefix> o).
--
-- Granularity: one socket per tmux session. If a second nvim launches in the
-- same session, serverstart errors (already-bound); pcall swallows it and the
-- first nvim wins. Acceptable trade-off for the sesh-style "one project per
-- session" workflow.
if vim.env.TMUX and not vim.env.NVIM then
  local session = vim.fn.system("tmux display-message -p '#S'"):gsub("\n", "")
  if session ~= "" then
    local sock = string.format("%s/nvim-tmux-%s.sock", vim.fn.stdpath("run"), session)
    pcall(vim.fn.serverstart, sock)
  end
end
