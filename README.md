# dotfiles

Personal config for Ghostty + fish + tmux + vim — multi-theme (Solarized Dark / Mocha / Frappé / Dracula / Gruvbox / Tokyo Night Storm / Nord / Catppuccin Latte / Rose Pine / Rose Pine Moon via `theme-set`) and multi-font (17 Nerd Fonts via `font-set`). Solarized Dark and JetBrains Mono are the defaults.

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

**4. `atuin import fish`** — one-time backfill of existing fish history
into the atuin sqlite store. Run after `brew bundle` (which installs
atuin) and after `bootstrap.sh` (which symlinks `~/.config/atuin/`):

```sh
atuin import fish
```

Safe to re-run (idempotent for already-imported rows). After this,
Ctrl-R opens atuin's picker (config at `.config/atuin/config.toml`).
Up stays on fish's native history-search.

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

Ten themes are wired: **Solarized Dark** (default), **Catppuccin Mocha**, **Catppuccin Frappé**, **Dracula**, **Gruvbox Dark Medium**, **Tokyo Night Storm**, **Nord**, **Catppuccin Latte** (the only light theme), **Rose Pine**, and **Rose Pine Moon**.
Swap via the fish function `theme-set`:

```fish
theme-set mocha        # switch to Catppuccin Mocha
theme-set frappe       # switch to Catppuccin Frappé (lifted bg, mauve accent)
theme-set dracula      # switch to Dracula
theme-set gruvbox      # switch to Gruvbox Dark Medium
theme-set tokyo-night  # switch to Tokyo Night Storm
theme-set nord         # switch to Nord (Frost-teal pastel prompt)
theme-set latte        # switch to Catppuccin Latte (light, partial coverage)
theme-set rose-pine    # switch to Rose Pine Main (light-on-accent, rose prompt)
theme-set rose-pine-moon # switch to Rose Pine Moon (2.5-contrast accessibility variant)
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

## 🐳 Sandbox

Run CLI/TUI tools you don't fully trust in an isolated Linux container that
shares your portable dotfiles env (fish, nvim, bat, eza, fzf, wt, …):

```fish
sandbox <name>          # create/reattach — drops into fish
sandbox <name> cmd ...  # run a one-shot command
sandbox --rm fish       # throwaway ephemeral shell
```

**Two modes:**

| Mode | Command | Isolation |
|------|---------|-----------|
| 🔒 Container (safe) | `sandbox <name>` | No host mounts. Named volume holds state. |
| ⚠️  Machine (trusted) | `sandbox machine create <name>` | Mounts your Mac home. **TRUSTED CODE ONLY.** |

🎨 The sandbox inherits your **current Mac theme** at entry — the named-theme
tools (bat, delta, glow, vivid, lnav, nvim, starship) match the host; switch
with `theme-set` on the Mac and re-enter, no rebuild needed.

**Lifecycle verbs:**

```fish
sandbox build           # (re)build the image
sandbox ls              # list all sandboxes
sandbox stop <name>     # stop (keep volume/state)
sandbox rm <name>       # remove container + volume
sandbox machine create <name>   # OrbStack machine — Mac home mounted
sandbox machine ssh <name>      # SSH into machine (fish shell)
sandbox machine ls              # list OrbStack machines
sandbox machine rm <name>       # delete machine
```

Container names round-trip: `sandbox ls` shows the bare `<name>`, which is what
`stop`/`rm`/reattach take (a pasted `sandbox-<name>` is accepted too).

**Flags** (for `sandbox <name>`):

```
--rm               ephemeral throwaway (no named volume)
-p PORT            publish PORT to 127.0.0.1 only (LAN off)
--mount DIR        bind-mount ONE dir at /home/dev/mnt
--env-file FILE    inject env vars (e.g. ~/sandbox/<name>/.env)
-e KEY=VAL         inject a single env var (repeatable)
--memory V         memory limit (default 2g)
--cpus V           CPU limit (default 2)
```

**Multi-shell:** open N Mac-tmux panes and run `sandbox <name>` in each —
they all `docker exec` into the same persistent container.

**Per-project runtimes:** the image bakes `node` (lts) and `go` (latest)
alongside the dotfiles tool set, but a project that pins a *specific* runtime
version in its own `.mise.toml` needs `mise install` to fetch it — the baked
`latest`/`lts` won't satisfy an exact pin. Inside a sandbox, clone a repo and
let its `.mise.toml` drive the toolchain:

```fish
git clone <repo> && cd <repo>
mise trust && mise install   # fetches the version this project pins
make                         # that version is now on $PATH
```

If a freshly installed tool isn't found yet (e.g. `make: go: No such file or
directory` because the project pins a version other than the baked one),
`cd .` re-fires mise's dir hook to load it.

**Secret injection:** use `--env-file ~/sandbox/<name>/.env` (or `-e KEY=VAL`)
to pass secrets at runtime. Never baked into the image.

**Named-volume config-snapshot caveat:** a persistent sandbox keeps the config
snapshot from when it was created. To pick up a rebuilt image:
`sandbox rm <name> && sandbox <name>`.

**Building the image:** `sandbox build` (or auto-triggered by `sandbox <name>`
when sources change). The build fetches pre-built binaries from GitHub releases,
so it needs a token to dodge the API rate limit — but it auto-uses
`gh auth token` when `GITHUB_TOKEN` isn't already set, so a `gh auth login` is
all you need. (`sandbox machine create` pulls the token from `gh` the same way.)

Smoke test: `scripts/test-sandbox.sh`.

## Keymaps quick-ref

- tmux prefix: `C-a`
- session switcher (tmux-sessionx): `<prefix> t`  (clock-mode moved to `<prefix> T`)
- pane nav: `<prefix> h/j/k/l` (prefix by choice; left-Option in Ghostty acts as Alt, right-Option still types Polish)
- splits: `<prefix> |` (right) / `<prefix> -` (down)
- window cycling: `<prefix> ,` (prev) / `<prefix> .` (next) — repeatable. Defaults `n`/`p` and `tmux-sensible`'s `C-p`/`C-n` are unbound; this is the only cycle pair.
- session cycling: `<prefix> Tab` (next) / `<prefix> S-Tab` (prev) / `<prefix> Space` (last) — repeatable. Defaults `(`/`)`/`L` unbound.
- window reorder: `<prefix> <` (left) / `<prefix> >` (right) — repeatable, focus follows the moved window.
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