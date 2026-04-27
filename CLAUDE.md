# dotfiles — Claude Code instructions

Personal Solarized + JetBrainsMono Nerd Font setup for Ghostty + tmux + vim + zsh.

## Conventions — don't drift from these

- **Manual symlinks via `bootstrap.sh`.** Don't introduce `stow`, `chezmoi`, or
  any other dotfiles manager unless asked.
- **`Brewfile` is report-only.** `bootstrap.sh` runs `brew bundle check` and
  prints what's missing — it does not install. Don't change that.
- **tmux status bar is hand-rolled** in `.config/tmux/tmux.conf` with
  Solarized base16 colors. Don't suggest theme plugins (catppuccin,
  tmux-powerline, etc.) — we deliberately avoid them.
- **tmux prefix is `C-a`** (screen-style; `C-Space` conflicts with macOS
  input-source switching). Pane nav: `<prefix> h/j/k/l` (Alt is reserved for
  Polish diacritics — never use `bind -n M-*`). Splits: `|` and `-`.
- **vim is intentionally minimal** (~30 lines, no plugin manager).
  Don't add vim-plug, LSP, or fuzzy finders without an explicit ask.
- **Solarized + JetBrainsMono Nerd Font everywhere.** No alternatives without
  asking.
- **Worktree status segment** uses `git rev-parse --git-dir` vs
  `--git-common-dir` for detection (works for `.claude/worktrees/*`,
  worktrunk paths, sibling worktrees alike). Don't replace with
  `git worktree list` parsing.

## Where things live

- Sources: `~/projects/dotfiles/{.config,.vimrc,.vim/colors}`
- Targets: `~/.config/{ghostty,tmux}`, `~/.vimrc`, `~/.vim/colors`
- Helpers: `.config/tmux/bin/tmux-{project-name,git-status}`
- Smoke tests for helpers: `scripts/test-helpers.sh`

## Out of scope (future work, separate spec)

- Moving `~/.zshrc` into the repo
- Lifting API tokens out of `~/.zshrc` into `~/.secrets`
- tmux ↔ `EnterWorktree` auto-window integration
