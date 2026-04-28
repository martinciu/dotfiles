" ~/.vimrc — minimal vim config (managed in $PROJECTS_HOME/dotfiles)

set nocompatible
set encoding=utf-8

" ─── UI ─────────────────────────────────────
set number
set relativenumber
set ruler
set cursorline
set showcmd
set wildmenu
set wildmode=list:longest,full
set belloff=all      " no audio bell, no visual flash, ever

" ─── Search ─────────────────────────────────
set hlsearch
set incsearch
set ignorecase
set smartcase

" ─── Indent ─────────────────────────────────
set autoindent
set smartindent
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2

" ─── Editing ────────────────────────────────
set backspace=indent,eol,start
set scrolloff=4
set sidescrolloff=8
set splitright
set splitbelow
set mouse=a
set clipboard=unnamed
set hidden

" ─── Persistent files ───────────────────────
set undofile
set undodir=~/.vim/undo//
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//

" ─── Color ──────────────────────────────────
set termguicolors
syntax on
filetype plugin indent on
set background=dark
silent! colorscheme solarized8

" ─── Leader maps ────────────────────────────
let mapleader = " "
nnoremap <leader><space> :nohlsearch<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
