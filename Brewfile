# Brewfile — packages this dotfiles repo depends on.
# Run `brew bundle --file=$PROJECTS_HOME/dotfiles/Brewfile` to install.

# Core
brew "git"
brew "tmux"
brew "crystal"  # compiles tmux-fingers from source on first `prefix + I` (TPM wizard always builds; no prebuilt binary)
brew "jq"   # JSON parsing in shell helpers
brew "gh"   # GitHub CLI — drives tmux-pr-detect + <prefix> P (gh pr view --web)
brew "bash"   # bash 5; pinned-shebang scripts target /opt/homebrew/bin/bash
brew "rsync"  # GNU rsync 3.x; shadows BSD openrsync — restores --info=progress2, -A (ACLs), -N (crtimes), --partial-dir

# Session switcher (sesh + fzf, sesh comes from a tap)
brew "fzf"
tap  "joshmedeski/sesh"
brew "joshmedeski/sesh/sesh"
brew "zoxide"  # frecency-ranked dir jumping; sesh picker source
brew "atuin"   # Ctrl-R history picker with exit-status markers + scope cycling; wired by .config/fish/conf.d/45-atuin.fish

# Worktree manager
brew "worktrunk"

# Issue tracker
brew "beads"  # `bd` — distributed graph issue tracker for AI agents; pulls dolt + icu4c@78 transitively. README "Manual extras" covers the `bd setup claude` one-time hook step.

# Runtime version manager (Node + Ruby) + Python package runner
brew "mise"
brew "uv"  # owns the Python lifecycle: interpreters (`uv python install --default`), projects (`uv add`/`run`/`sync`), CLIs (`uv tool`), pip-shim (`uv pip`)

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
brew "lnav"                     # TUI log file navigator
brew "fish"                     # primary interactive shell
brew "tealdeer"                 # `tldr` — community-driven command examples (Rust, fast)

# Code search & refactoring
brew "ast-grep"                 # structural code search/rewrite (AST patterns, multi-language)

# Shell script linting & formatting
brew "shellcheck"               # bash/sh static analysis (quoting bugs, unused vars, POSIX/bashism mismatches)
brew "shfmt"                    # POSIX/bash/mksh formatter (`-d` for diff, `-w` to write)

# System monitoring & benchmarking
brew "btop"                     # modern top replacement (themed Solarized)
brew "dua-cli"                  # interactive disk-usage analyzer (TUI: `dua i`)
brew "duf"                      # modern df replacement (grouped, color-coded)
brew "dust"                     # tree-style du replacement (largest-first, bar graphs)
brew "hyperfine"                # command benchmarking (warmups, multi-run stats)

# Fonts — JetBrains Mono is the default; others are switchable via `font-set`
cask "font-jetbrains-mono-nerd-font"  # default; Solarized + JetBrainsMono Nerd Font everywhere (CLAUDE.md)
cask "font-fira-code-nerd-font"       # popular ligature font; widest ligature set
cask "font-caskaydia-cove-nerd-font"  # Cascadia Code (Nerd Fonts rename); Windows Terminal default
cask "font-monaspice-nerd-font"       # GitHub Monaspace (Nerd Fonts ships it as "Monaspice"); texture healing, multi-style superfamily
cask "font-iosevka-nerd-font"         # narrow, sharp on Retina; more columns per window
cask "font-hack-nerd-font"            # popular open-source classic; no ligatures
cask "font-meslo-lg-nerd-font"        # Powerlevel10k's recommended default
cask "font-sauce-code-pro-nerd-font"  # Adobe Source Code Pro (Nerd Fonts rename: SauceCodePro)
cask "font-ubuntu-mono-nerd-font"     # Canonical's monospace; distinctive curves
cask "font-inconsolata-nerd-font"     # Raph Levien's humanist classic
cask "font-departure-mono-nerd-font"  # Helena Zhang's pixel display monospace (2024); retro CRT vibe
cask "font-bigblue-terminal-nerd-font" # IBM PC OEM CP437 pixel bitmap; classic DOS/BIOS look
cask "font-0xproto-nerd-font"         # 0xType's "0xProto" — designed for programming, with ligatures
cask "font-3270-nerd-font"            # IBM 3270 mainframe terminal font; tall, narrow, archival
cask "font-hurmit-nerd-font"          # Hermit (Nerd Fonts ships as "Hurmit"); minimalist humanist
cask "font-monofur-nerd-font"         # Monofur — quirky, hand-drawn curves, no ligatures
cask "font-opendyslexic-nerd-font"    # OpenDyslexic — weighted bottoms; aids dyslexic readers
