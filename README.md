# dotfiles

Personal config for Ghostty + zsh + tmux + vim, all in Solarized + JetBrainsMono Nerd Font.

## Cheatsheets

Solarized-themed quick references — also browseable at
[martinciu.github.io/dotfiles](https://martinciu.github.io/dotfiles/):

- [Neovim](https://martinciu.github.io/dotfiles/nvim-cheatsheet.html) — LazyVim leader map, picker, LSP, neotest, Mason/Lazy
- [tmux](https://martinciu.github.io/dotfiles/tmux-cheatsheet.html) — prefix `C-a` map, sessions/windows/panes, tmux-sessionx picker, status bar, copy mode
- [Terminal](https://martinciu.github.io/dotfiles/terminal-cheatsheet.html) — eza, bat, less wrapper, git-delta, difftastic, glow, vivid, fzf, zsh plugins

## Setup (new machine)

Detailed conventions and reasoning live in `CLAUDE.md`. This section is the
operational checklist.

1. Install Homebrew (https://brew.sh).
2. Export `PROJECTS_HOME` (e.g. `export PROJECTS_HOME="$HOME/code"`) and
   clone this repo to `$PROJECTS_HOME/dotfiles`.
3. Install brew packages: `brew bundle --file=$PROJECTS_HOME/dotfiles/Brewfile`.
4. Run the symlinker: `$PROJECTS_HOME/dotfiles/bootstrap.sh` (idempotent;
   safe to re-run).
5. Apply the **manual extras** below — `bootstrap.sh` cannot automate these.
6. Open tmux and press `<prefix> I` (capital I, prefix = `C-a`) to install
   TPM plugins.

### Manual extras

**1. `~/.zshrc.local`** — per-machine env (e.g. `PROJECTS_HOME` and any
secrets paths).

```sh
cp $PROJECTS_HOME/dotfiles/.zshrc.local.template ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

**2. `~/.config/sesh/sesh.local.toml`** — `bootstrap.sh` copies the template
on first run. Edit it to add machine-local project sessions; the shared
`sesh.toml` is the wrong place for them.

**3. Wire delta into git** (one-time, global).

```sh
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.syntax-theme "Solarized (dark)"
```

**4. Claude Code window-title hooks.** `~/.claude/settings.json` is not
symlinked from this repo (it accumulates machine-local permission state),
so this is a one-time manual edit. Add (or merge into) the top-level
`hooks` object:

```json
"SessionStart": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/claude-tmux-window-name set" } ] }
],
"Stop": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/claude-tmux-window-name set" } ] }
],
"SessionEnd": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/claude-tmux-window-name clear" } ] }
]
```

These drive the `claude[<name>]` window title (tmux's
`automatic-rename-format` reads `@claude_session_name`).

## What's where

| Tool         | Source path                          | Target              |
| ------------ | ------------------------------------ | ------------------- |
| Ghostty      | `.config/ghostty/`                   | `~/.config/ghostty` |
| tmux         | `.config/tmux/`                      | `~/.config/tmux`    |
| nvim         | `.config/nvim/`                      | `~/.config/nvim`    |
| vim          | `.vimrc`, `.vim/colors/`             | `~/.vimrc`, `~/.vim/colors` |
| zsh          | `.zshrc`, `.p10k.zsh`                | `~/.zshrc`, `~/.p10k.zsh` |
| sesh         | `.config/sesh/sesh.toml`             | `~/.config/sesh/sesh.toml` |
| worktrunk    | `.config/worktrunk/`                 | `~/.config/worktrunk` |
| glow         | `.config/glow/`                      | `~/.config/glow` |
| tailspin     | `.config/tailspin/`                  | `~/.config/tailspin` |
| lnav         | `.config/lnav/{configs,formats}/installed/` | `~/.config/lnav/{configs,formats}/installed` |
| btop         | `.config/btop/`                      | `~/.config/btop`    |
| procs        | `.config/procs/`                     | `~/.config/procs`   |
| ccstatusline | `.config/ccstatusline/`              | `~/.config/ccstatusline` |
| Claude       | `.claude/CLAUDE.md`                  | `~/.claude/CLAUDE.md` |
| user bin     | `bin/*` (e.g. `s`)                   | `~/.local/bin/*`    |

## Keymaps quick-ref

- tmux prefix: `C-a`
- session switcher (tmux-sessionx): `<prefix> t`  (clock-mode moved to `<prefix> T`)
- pane nav: `<prefix> h/j/k/l` (Alt is reserved for Polish diacritics)
- splits: `<prefix> |` (right) / `<prefix> -` (down)
- URL picker (current pane): `<prefix> u`
- file picker (current pane → nvim): `<prefix> o`
- reload tmux: `<prefix> r`
- TPM plugin install: `<prefix> I` (capital I)
- worktree+session command (any shell): `s [<project>] [<name>]` — inside tmux 1 arg = worktree name in current project; outside tmux 1 arg = project name (attach), 0 args = fzf picker

## Status bar (right side)

`<project> · <git/worktree>`

- Project chip (violet) is the top-level dir under `$PROJECTS_HOME`.
- Git chip is **cyan** in main checkout, **yellow** in a worktree.
  Worktree label `wt:NAME` only shows when branch name differs from worktree dir name.

## Quirks

- URLs in tmux panes open with **Shift+Cmd+click**, not Cmd+click.
- Why: with `set -g mouse on`, Ghostty defers all mouse interactions (incl. URL hover/click detection) to tmux. Ghostty's default `mouse-shift-capture = false` makes Shift the bypass modifier — Shift releases the click from tmux and Cmd reaches Ghostty's URL handler.
- Or, keyboard-only: `<prefix> u` opens an fzf picker of URLs from the current pane (visible + last 2000 lines), Enter opens in the default browser. Provided by [`wfxr/tmux-fzf-url`](https://github.com/wfxr/tmux-fzf-url).
- File-reference links printed by Claude Code (OSC 8 hyperlinks to `file:///abs/path`) open with **Shift+Cmd+click** — same modifier as URLs. Routing to VS Code (or whichever editor) happens via the existing macOS file-type defaults (Finder → Get Info → "Open with" → "Change All"); no extra config in this repo.
- Smoke-test that the chain works end-to-end:

  ```sh
  printf '\e]8;;file://%s/.zshrc\e\\.zshrc\e]8;;\e\\\n' "$HOME"
  ```

  Shift+Cmd+click the rendered "`.zshrc`" — your default `.zshrc` editor should open the file.
- File-path picker (`<prefix> o`): scans the current pane + 2000 scrollback
  lines for paths that exist on disk (OSC 8 hyperlinks + plain `path:line`
  regex), fzf-picks one, jumps the per-session nvim. Falls back to a fresh
  nvim in a new tmux window if no live nvim socket exists for the session.
