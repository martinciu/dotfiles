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
