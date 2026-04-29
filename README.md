# dotfiles

Personal config for Ghostty + zsh + tmux + vim, all in Solarized + JetBrainsMono Nerd Font.

## What's where

| Tool      | Source path                          | Target              |
| --------- | ------------------------------------ | ------------------- |
| Ghostty   | `.config/ghostty/`                   | `~/.config/ghostty` |
| tmux      | `.config/tmux/`                      | `~/.config/tmux`    |
| nvim      | `.config/nvim/`                      | `~/.config/nvim`    |
| vim       | `.vimrc`, `.vim/colors/`             | `~/.vimrc`, `~/.vim/colors` |
| zsh       | `.zshrc`, `.p10k.zsh`                | `~/.zshrc`, `~/.p10k.zsh` |
| sesh      | `.config/sesh/sesh.toml`             | `~/.config/sesh/sesh.toml` |
| worktrunk | `.config/worktrunk/config.toml`      | `~/.config/worktrunk/config.toml` |
| glow      | `.config/glow/glamour.json`          | `~/.config/glow/glamour.json` |

## Keymaps quick-ref

- tmux prefix: `C-a`
- session switcher (sesh picker): `<prefix> t`  (clock-mode moved to `<prefix> T`)
- pane nav: `<prefix> h/j/k/l` (Alt is reserved for Polish diacritics)
- splits: `<prefix> |` (right) / `<prefix> -` (down)
- URL picker (current pane): `<prefix> u`
- reload tmux: `<prefix> r`
- TPM plugin install: `<prefix> I` (capital I)

## Status bar (right side)

`<project> · <git/worktree>`

- Project chip (violet) is the top-level dir under `$PROJECTS_HOME`.
- Git chip is **cyan** in main checkout, **yellow** in a worktree.
  Worktree label `wt:NAME` only shows when branch name differs from worktree dir name.

## Quirks

- URLs in tmux panes open with **Shift+Cmd+click**, not Cmd+click.
- Why: with `set -g mouse on`, Ghostty defers all mouse interactions (incl. URL hover/click detection) to tmux. Ghostty's default `mouse-shift-capture = false` makes Shift the bypass modifier — Shift releases the click from tmux and Cmd reaches Ghostty's URL handler.
- Or, keyboard-only: `<prefix> u` opens an fzf picker of URLs from the current pane (visible + last 2000 lines), Enter opens in the default browser. Provided by [`wfxr/tmux-fzf-url`](https://github.com/wfxr/tmux-fzf-url).

## Future work

- Lift API tokens out of `~/.zshrc` into a gitignored `~/.secrets`
- `EnterWorktree` ↔ tmux integration (auto-spawn window per worktree)
