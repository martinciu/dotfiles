# dotfiles

Personal config for Ghostty + zsh + tmux + vim, all in Solarized + JetBrainsMono Nerd Font.

## What's where

| Tool    | Source path                          | Target              |
| ------- | ------------------------------------ | ------------------- |
| Ghostty | `.config/ghostty/`                   | `~/.config/ghostty` |
| tmux    | `.config/tmux/`                      | `~/.config/tmux`    |
| vim     | `.vimrc`, `.vim/colors/`             | `~/.vimrc`, `~/.vim/colors` |
| zsh     | (still in `~/.zshrc`, not yet here)  | —                   |

## Keymaps quick-ref

- tmux prefix: `C-a`
- session switcher: `<prefix> T`
- pane nav: `<prefix> h/j/k/l` (Alt is reserved for Polish diacritics)
- splits: `<prefix> |` (right) / `<prefix> -` (down)
- reload tmux: `<prefix> r`
- TPM plugin install: `<prefix> I` (capital I)

## Status bar (right side)

`<project> · <git/worktree> · <clock>`

- Project chip (violet) is the top-level dir under `$PROJECTS_HOME`.
- Git chip is **cyan** in main checkout, **yellow** in a worktree.
  Worktree label `wt:NAME` only shows when branch name differs from worktree dir name.

## Quirks

- URLs in tmux panes open with **Shift+Cmd+click**, not Cmd+click.
- Why: with `set -g mouse on`, Ghostty defers all mouse interactions (incl. URL hover/click detection) to tmux. Ghostty's default `mouse-shift-capture = false` makes Shift the bypass modifier — Shift releases the click from tmux and Cmd reaches Ghostty's URL handler.

## Future work

- Move `~/.zshrc` and `~/.p10k.zsh` into the repo
- Lift API tokens out of `~/.zshrc` into a gitignored `~/.secrets`
- `EnterWorktree` ↔ tmux integration (auto-spawn window per worktree)
- If `worktrunk` is not in homebrew-core: install via `cargo install worktrunk`
