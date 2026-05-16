# dotfiles

Personal config for Ghostty + fish + tmux + vim — multi-theme (Solarized Dark / Mocha / Frappé / Dracula / Gruvbox / Tokyo Night Storm / Catppuccin Latte via `theme-set`) and multi-font (17 Nerd Fonts via `font-set`). Solarized Dark and JetBrains Mono are the defaults.

<p align="center">
  <a href="docs/images/example_terminal.png"><img src="docs/images/example_terminal-thumb.png" alt="terminal" width="32%" /></a>
  <a href="docs/images/example_tmux.png"><img src="docs/images/example_tmux-thumb.png" alt="tmux" width="32%" /></a>
  <a href="docs/images/example_vim.png"><img src="docs/images/example_vim-thumb.png" alt="vim" width="32%" /></a>
</p>

## Cheatsheets

Solarized-themed quick references — also browseable at
[martinciu.github.io/dotfiles](https://martinciu.github.io/dotfiles/):

- [Terminal](https://martinciu.github.io/dotfiles/terminal-cheatsheet.html) — eza, bat, less wrapper, git-delta, difftastic, glow, vivid, xh, duf, dust, dua, fzf
- [tmux](https://martinciu.github.io/dotfiles/tmux-cheatsheet.html) — prefix `C-a` map, sessions/windows/panes, tmux-sessionx picker, status bar, copy mode
- [Neovim](https://martinciu.github.io/dotfiles/nvim-cheatsheet.html) — LazyVim leader map, picker, LSP, neotest, Mason/Lazy

## Setup (new machine)

Detailed conventions and reasoning live in `CLAUDE.md`. This section is the
operational checklist.

1. Install Homebrew (https://brew.sh).
2. Export `PROJECTS_HOME` (e.g. `export PROJECTS_HOME="$HOME/code"`) and
   clone this repo to `$PROJECTS_HOME/dotfiles`.
3. Install brew packages: `brew bundle --file=$PROJECTS_HOME/dotfiles/Brewfile`.
4. Run the symlinker: `$PROJECTS_HOME/dotfiles/bootstrap.sh` (idempotent;
   safe to re-run). Also installs uv-managed CPython 3.13 as the global
   `python3` (`~/.local/bin/python3`); Apple's stays at `/usr/bin/python3`
   for system use.
5. Apply the **manual extras** below — `bootstrap.sh` cannot automate these.
6. Open tmux and press `<prefix> I` (capital I, prefix = `C-a`) to install
   TPM plugins.

### Manual extras

**1. Login shell — fish.** `bootstrap.sh` installs the fish config and copies
`15-local.fish` / `99-secrets.fish` from templates, but it does *not* change
your login shell. Enable manually:

```sh
# One-time: register fish as a valid login shell
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells

# Edit the per-machine fish overlays:
$EDITOR ~/.config/fish/conf.d/15-local.fish    # PROJECTS_HOME, PATH overrides
$EDITOR ~/.config/fish/conf.d/99-secrets.fish  # API keys etc.

# Switch login shell to fish
chsh -s /opt/homebrew/bin/fish
```

After `chsh`, open a new Ghostty tab (or `exec /opt/homebrew/bin/fish` to
hot-swap an existing pane).

**2. `~/.config/sesh/sesh.local.toml`** — `bootstrap.sh` copies the template
on first run. Edit it to add machine-local project sessions; the shared
`sesh.toml` is the wrong place for them.

**3. Wire delta into git** (one-time, global). The include line picks up
delta's theme + chip tweaks from the active theme (see "Switching themes"
below — `theme-set` flips the included file).

```sh
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global include.path "~/.config/themes/delta-current.gitconfig"
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

**5. tmux-agent-status hooks.** Same per-machine pattern as item 4 —
`~/.claude/settings.json` is not symlinked from this repo, so wiring
the four hook entries is manual. After `prefix + I` inside tmux
installs the upstream plugin via TPM, merge these into the same
top-level `hooks` object. Hooks point at a dotfiles-owned wrapper
(`bin/tmux-agent-status-hook`) rather than the plugin's own
`better-hook.sh` — see the "why a wrapper" note below. Where an array
already exists (e.g. `UserPromptSubmit` and `PreToolUse` host
ccstatusline; `Stop` hosts `claude-tmux-window-name set`), append the
new entry as a sibling — do not nest:

```json
"UserPromptSubmit": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/tmux-agent-status-hook UserPromptSubmit" } ] }
],
"PreToolUse": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/tmux-agent-status-hook PreToolUse" } ] }
],
"Stop": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/tmux-agent-status-hook Stop" } ] }
],
"Notification": [
  { "hooks": [ { "type": "command",
    "command": "~/.config/tmux/bin/tmux-agent-status-hook Notification" } ] }
]
```

These drive the agent-status chip in the right cluster of the tmux
status bar (left of the PR pin): **cyan** when any Claude Code session
is actively responding; **red** when one or more sessions are in
operator-marked wait mode (set via `<prefix> W`); muted **"N ready"**
when all sessions are settled — finished a turn *or* blocked on a
permission prompt (both `Stop` and `Notification` write `done`, so the
chip does not distinguish them); hidden when no sessions are tracked.
The wrapper keys each session by tmux session name (via
`tmux display-message`), sanitizing `/` → `_` in the path, not by
Claude's session id.

*Why a wrapper instead of pointing at the plugin's `better-hook.sh`
directly?* The upstream plugin builds flat cache paths like
`$STATUS_DIR/<session>.status` and chokes when session names contain
`/` — which is exactly the `s` worktree-session convention
(`<project>/<branch>`). The wrapper sanitizes `/` → `_` before writing,
so `dotfiles/231-tmux-agent-status` becomes
`dotfiles_231-tmux-agent-status.status` instead of a broken nested path.
The plugin's switcher and popup read the same cache files, so they see
our writes too. The durable fix is to land the sanitization upstream
in `samleeney/tmux-agent-status`.


## What's where

| Tool         | Source path                          | Target              |
| ------------ | ------------------------------------ | ------------------- |
| [Ghostty](https://ghostty.org/) | `.config/ghostty/`        | `~/.config/ghostty` |
| [tmux](https://github.com/tmux/tmux) | `.config/tmux/`      | `~/.config/tmux`    |
| [nvim](https://neovim.io/) | `.config/nvim/`                | `~/.config/nvim`    |
| [vim](https://www.vim.org/) | `.vimrc`, `.vim/colors/`      | `~/.vimrc`, `~/.vim/colors` |
| [fish](https://fishshell.com/) | `.config/fish/`              | `~/.config/fish/`   |
| [sesh](https://github.com/joshmedeski/sesh) | `.config/sesh/sesh.toml` | `~/.config/sesh/sesh.toml` |
| [worktrunk](https://worktrunk.dev/) | `.config/worktrunk/` | `~/.config/worktrunk` |
| [glow](https://github.com/charmbracelet/glow) | `.config/glow/` | `~/.config/glow` |
| [tailspin](https://github.com/bensadeh/tailspin) | `.config/tailspin/` | `~/.config/tailspin` |
| [lnav](https://lnav.org/) | `.config/lnav/{configs,formats}/installed/` | `~/.config/lnav/{configs,formats}/installed` |
| [btop](https://github.com/aristocratos/btop) | `.config/btop/` | `~/.config/btop`    |
| [procs](https://github.com/dalance/procs) | `.config/procs/` | `~/.config/procs`   |
| [xh](https://github.com/ducaale/xh) | `.config/xh/` | `~/.config/xh` |
| [ccstatusline](https://github.com/sirmalloc/ccstatusline) | `.config/ccstatusline/` | `~/.config/ccstatusline` |
| [Claude](https://claude.com/claude-code) | `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| user bin     | `bin/*` (e.g. `s`)                   | `~/.local/bin/*`    |

## Switching themes

Seven themes are wired: **Solarized Dark** (default), **Catppuccin Mocha**, **Catppuccin Frappé**, **Dracula**, **Gruvbox Dark Medium**, **Tokyo Night Storm**, and **Catppuccin Latte** (the first and only light theme).
Swap via the fish function `theme-set`:

```fish
theme-set mocha        # switch to Catppuccin Mocha
theme-set frappe       # switch to Catppuccin Frappé (lifted bg, mauve accent)
theme-set dracula      # switch to Dracula
theme-set gruvbox      # switch to Gruvbox Dark Medium
theme-set tokyo-night  # switch to Tokyo Night Storm
theme-set latte        # switch to Catppuccin Latte (light, partial coverage)
theme-set solarized    # switch back
```

**Latte caveat:** Catppuccin Latte is the only light theme and ships with **partial tier-1 coverage** — only Ghostty, tmux, and starship have Latte variants. delta, glow, gh-dash, lnav, and nvim keep their previous (dark) theme during a Latte session. Issue #215 tracks the full-coverage follow-up.

The function flips per-tool symlinks under `~/.config/themes/`,
`~/.config/ghostty/theme.ghostty`, `~/.config/starship.toml`,
`~/.config/glow/glamour.json`, `~/.config/gh-dash/config.yml`,
`~/.config/lnav/configs/installed/theme.json`, plus a
`delta-current.gitconfig` snippet included via the gitconfig
`include.path` directive set up during `Setup` above. It also sets
`$BAT_THEME` and `$VIVID_THEME` as fish universal variables (read by
bat and `vivid generate` at shell start, respectively). fzf colors are
palette-symbolic in `FZF_DEFAULT_OPTS` and auto-adapt via Ghostty's
16-color palette — no env var needed.

**Reloads live:** tmux (status bar + helpers, instant), ghostty,
starship (next prompt render), glow, delta (next `git diff`).

**Needs restart:** open shells (`$BAT_THEME` and `$VIVID_THEME` are
read at fish startup; affects bat + ls/eza file colors), nvim,
gh-dash, lnav.

**Add another theme:** drop a new `.config/themes/<name>.tmux` palette
file (mirror the role keys from the existing palettes) plus per-tool
`*-<name>.<ext>` variant configs, then extend the `switch` statement
in `.config/fish/functions/theme-set.fish`.

Smoke test: `scripts/test-theme-switch.sh`.

## Keymaps quick-ref

- tmux prefix: `C-a`
- session switcher (tmux-sessionx): `<prefix> t`  (clock-mode moved to `<prefix> T`)
- pane nav: `<prefix> h/j/k/l` (Alt is reserved for Polish diacritics)
- splits: `<prefix> |` (right) / `<prefix> -` (down)
- reload tmux: `<prefix> r`
- TPM plugin install: `<prefix> I` (capital I)
- worktree+session command (any shell): `s [<project>] [<name>]` — inside tmux 1 arg = worktree name in current project; outside tmux 1 arg = project name (attach), 0 args = fzf picker. Branch name verbatim — the `worktree-` prefix is reserved for the `EnterWorktree` workflow.

## Status bar (right side)

`<project> · <git/worktree>`

- Project chip (violet) is the top-level dir under `$PROJECTS_HOME`.
- Git chip is **cyan** in main checkout, **yellow** in a worktree.
  Worktree label `wt:NAME` only shows when branch name differs from worktree dir name.

## Quirks

- URLs in tmux panes open with **Shift+Cmd+click**, not Cmd+click.
- Why: with `set -g mouse on`, Ghostty defers all mouse interactions (incl. URL hover/click detection) to tmux. Ghostty's default `mouse-shift-capture = false` makes Shift the bypass modifier — Shift releases the click from tmux and Cmd reaches Ghostty's URL handler.
- File-reference links printed by Claude Code (OSC 8 hyperlinks to `file:///abs/path`) open with **Shift+Cmd+click** — same modifier as URLs. Routing to VS Code (or whichever editor) happens via the existing macOS file-type defaults (Finder → Get Info → "Open with" → "Change All"); no extra config in this repo.
- Smoke-test that the chain works end-to-end:

  ```sh
  printf '\e]8;;file://%s/.config/fish/config.fish\e\\config.fish\e]8;;\e\\\n' "$HOME"
  ```

  Shift+Cmd+click the rendered "`config.fish`" — your default editor for that file type should open it.
- **Dashboard (`bin/dashboard`) is experimental.** Spawns a tiled
  `dashboard-<derived>` session that polls `capture-pane` for every
  matched session — useful for keeping eyes on N parallel runs at
  once. Wired up and tested for the author's daily flow, but not
  battle-hardened: edge cases around layout, pagination, and
  re-discovery may misbehave. Expect the surface (flags, bindings,
  session-name shape) to shift. Cheatsheet card:
  [`docs/tmux-cheatsheet.html`](docs/tmux-cheatsheet.html#dashboard).
