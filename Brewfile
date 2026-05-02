# Brewfile — packages this dotfiles repo depends on.
# Run `brew bundle --file=$PROJECTS_HOME/dotfiles/Brewfile` to install.

# Core
brew "git"
brew "tmux"
brew "jq"   # JSON parsing in shell helpers

# Session switcher (sesh + fzf, sesh comes from a tap)
brew "fzf"
tap  "joshmedeski/sesh"
brew "joshmedeski/sesh/sesh"
brew "zoxide"  # frecency-ranked dir jumping; sesh picker source

# Worktree manager
brew "worktrunk"

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
brew "procs"                    # modern ps replacement (Rust)
brew "zsh-syntax-highlighting"  # live command-line highlighting
brew "zsh-autosuggestions"      # ghost-text completion from history
brew "fzf-tab"                  # fzf-driven Tab completion menu

# System monitoring
brew "btop"                     # modern top replacement (themed Solarized)
