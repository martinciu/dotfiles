# Brewfile — packages this dotfiles repo depends on.
# Run `brew bundle --file=$PROJECTS_HOME/dotfiles/Brewfile` to install.

# Core
brew "git"
brew "tmux"
brew "jq"   # JSON parsing in shell helpers
brew "gh"   # GitHub CLI — drives tmux-pr-detect + <prefix> P (gh pr view --web)
brew "watch"  # procps watch — used by `dashboard` for live tile polling (-c ANSI passthrough)
brew "bash"   # bash 5; pinned-shebang scripts target /opt/homebrew/bin/bash
brew "rsync"  # GNU rsync 3.x; shadows BSD openrsync — restores --info=progress2, -A (ACLs), -N (crtimes), --partial-dir

# Session switcher (sesh + fzf, sesh comes from a tap)
brew "fzf"
tap  "joshmedeski/sesh"
brew "joshmedeski/sesh/sesh"
brew "zoxide"  # frecency-ranked dir jumping; sesh picker source

# Worktree manager
brew "worktrunk"

# Runtime version manager (Node + Ruby) + Python package runner
brew "mise"
brew "uv"  # fast Python package manager + ephemeral-venv runner; "uv run --with pyyaml script.py" without polluting global Python

# Editor — neovim IDE (LazyVim)
brew "neovim"
brew "ripgrep"   # snacks.picker live grep
brew "fd"        # snacks.picker file find
brew "lazygit"   # <leader>gg in LazyVim
brew "tree-sitter-cli" # nvim-treesitter parser builds

# Shell colors & appearance
brew "eza"                      # ls replacement with icons + git status
brew "bat"                      # syntax-highlighted cat / man pager backend
brew "git-delta"                # git diff/log/blame pager
brew "difftastic"               # syntactic diff for ad-hoc compares (non-git)
brew "glow"                     # render markdown to ANSI
brew "tailspin"                 # syntax-highlighted log viewer (tspin)
brew "vivid"                    # generates LS_COLORS palettes
brew "starship"                 # cross-shell prompt engine (Rust); replaces powerlevel10k
brew "procs"                    # modern ps replacement (Rust)
brew "xh"                       # modern HTTP client (HTTPie-compatible CLI, Solarized-aware)
brew "zsh-syntax-highlighting"  # live command-line highlighting
brew "zsh-autosuggestions"      # ghost-text completion from history
brew "fzf-tab"                  # fzf-driven Tab completion menu
brew "lnav"                     # TUI log file navigator
brew "fish"                     # alternative interactive shell (trial)

# Code search & refactoring
brew "ast-grep"                 # structural code search/rewrite (AST patterns, multi-language)

# Shell script linting & formatting
brew "shellcheck"               # zsh/bash/sh static analysis (quoting bugs, unused vars, POSIX/bashism mismatches)
brew "shfmt"                    # POSIX/bash/mksh formatter (`-d` for diff, `-w` to write)

# System monitoring & benchmarking
brew "btop"                     # modern top replacement (themed Solarized)
brew "hyperfine"                # command benchmarking (warmups, multi-run stats)

# Fonts
cask "font-jetbrains-mono-nerd-font"  # Solarized + JetBrainsMono Nerd Font everywhere (CLAUDE.md)
