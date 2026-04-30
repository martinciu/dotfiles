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
- **TPM is the tmux plugin manager.** Loaded plugins: `tmux-sensible`,
  `tmux-resurrect`, `tmux-continuum` (`@continuum-restore 'on'` —
  auto-restores the last saved env on tmux start), `tmux-fzf-url`. Don't
  remove TPM ("we hand-roll everything") without an explicit ask — the
  status bar is hand-rolled, behavior plugins aren't.
- **tmux URL picker is `<prefix> u` via `tmux-fzf-url`** (`wfxr/tmux-fzf-url`,
  loaded by TPM). Scope is visible pane + 2000-line scrollback (not the full
  50k history). Popup geometry matches the sesh picker (`-w 70% -h 70%`).
  `--tac` is intentional so the newest URL lands at the cursor — don't drop
  it. Don't replace with a custom shell script; the plugin already does
  regex extraction efficiently.
- **Sesh config is split: shared + machine-local.** The repo tracks
  `.config/sesh/sesh.toml` (symlinked into `~/.config/sesh/sesh.toml`)
  with a `Home 🏠` session for `~` and a top-level
  `import = ["~/.config/sesh/sesh.local.toml"]` directive. Machine-local
  project sessions go in `~/.config/sesh/sesh.local.toml` (untracked,
  outside the repo, copied from `sesh.local.toml.template` by
  `bootstrap.sh` on first run). Don't add machine-specific entries to
  the shared file; don't drop the `import` line — sesh hard-errors on
  a missing import target. The picker (`<prefix> t`, swapped with the
  default clock-mode binding which moved to `<prefix> T`) is
  `sesh picker -i -d -H` — full vanilla, all sources (configured /
  tmux / zoxide / tmuxinator). Don't re-introduce a custom fzf wrapper
  script. Zoxide is on but `_ZO_EXCLUDE_DIRS` blocks `~/`,
  `~/Downloads/*`, `~/.config/*`, `~/Library/*` from being indexed —
  keeps the picker focused on real projects under `$PROJECTS_HOME`.
- **`vim` and `vimdiff` are zsh aliases to nvim**; **`vi` is a zsh alias
  to the legacy minimal vim** (`alias vi='command vim'` — `command`
  suppresses recursive alias expansion). All three are defined in
  `.zshrc`, guarded on `command -v nvim`. The minimal vim config
  (`.vimrc` ~30 lines, no plugin manager, `.vim/colors/solarized8.vim`)
  is reachable via `vi`, `command vim`, or `\vim`. Don't add vim-plug,
  LSP, or fuzzy finders to the minimal vim config without an explicit
  ask.
- **nvim is built on LazyVim**, themed Solarized, configured at
  `.config/nvim/`. Don't replace LazyVim with another distro or
  hand-roll a different plugin manager without an explicit ask.
- **LazyVim Alt-keymaps removed** in `lua/config/keymaps.lua`
  (`<A-j>/<A-k>`) — Alt is reserved for Polish diacritics. Don't
  re-add Alt bindings.
- **Mason-managed LSPs are pinned** via `mason-lock.json`. The lockfile
  is committed. `:MasonLock` snapshots the current state; `:MasonLockUpdate`
  upgrades to latest then snapshots — use the latter to bump versions.
- **`lazy-lock.json` and `mason-lock.json` are committed** for
  reproducibility across machines.
- **Solarized + JetBrainsMono Nerd Font everywhere.** No alternatives without
  asking.
- **wt user config is symlinked from `.config/worktrunk/config.toml`.**
  Per-project hook approvals (`approvals.toml`) are machine-local and
  gitignored.
- **Worktree status segment** uses `git rev-parse --git-dir` vs
  `--git-common-dir` for detection (works for `.claude/worktrees/*`,
  worktrunk paths, sibling worktrees alike). Don't replace with
  `git worktree list` parsing.
- **tmux window name follows the active pane's last typed command.**
  zsh `preexec` hook (`_tmux_record_last_cmd` in `.zshrc`) sets a per-pane
  `@last_cmd` user variable; `tmux.conf` enables `automatic-rename` with a
  format that reads it. Env-var assignments are stripped, then the first
  two whitespace-separated tokens are used. `allow-rename off` stays so
  OSC titles from apps (e.g. Claude Code) cannot override. Don't replace
  with `automatic-rename off` or wire app-specific renames without an
  explicit ask. The label function `_tmux_window_label` in `.zshrc` is
  duplicated in `scripts/test-tmux-window-label.zsh` — keep both copies
  in sync.
- **Bells are silenced at every layer** (Ghostty `bell-features =`, zsh
  `unsetopt BEEP/HIST_BEEP/LIST_BEEP`, vim `belloff=all`, tmux
  `bell-action/visual-bell/monitor-bell off`). Don't re-enable without
  an explicit ask.
- **Shell colors are Solarized Dark, end-to-end.** Tools: `eza` (ls),
  `bat` (cat + `MANPAGER`), `git-delta` (git pager), `glow` (`md` markdown
  renderer), `vivid` (`LS_COLORS`), `zsh-syntax-highlighting`,
  `zsh-autosuggestions`, `fzf-tab` (Tab completion picker). Palette pins:
  `vivid generate solarized-dark`, `bat --theme="Solarized (dark)"`,
  `delta.syntax-theme = "Solarized (dark)"`,
  `md` alias passes `--style .config/glow/glamour.json` (chroma
  `solarized-dark` for fenced code blocks). Don't swap themes or
  introduce alternatives (`exa`, `lsd`, `diff-so-fancy`, `mdcat`, etc.)
  without asking. Plugin source order in `.zshrc` is fixed: fzf →
  `bindkey -r '^[c'` (Alt-C unbind) → zoxide → fzf-tab →
  zsh-autosuggestions → zsh-syntax-highlighting (must be last).
  fzf-tab needs fzf's `^I` binding already in place and must be sourced
  before any plugin that wraps widgets. The first-time `git config`
  recipe wiring delta as git's pager
  lives in **First-time setup on a new machine** below.
- **Interactive `less` is a `bat` wrapper** (defined in `.zshrc` next to the
  `cat` alias). Files get bat's full decoration; piped input uses `--plain` so
  `cmd | less` stays clean. `command less` reaches real `less` for `less +F`,
  `-R`, etc. Don't replace with `alias less='bat …'` — the function exists so
  stdin doesn't get bat's `STDIN` header. Don't set `$PAGER=bat` globally —
  git/delta and other tools manage their own pager.
- **`md` renders markdown via `glow`** with a pinned Solarized JSON style at
  `.config/glow/glamour.json`. `bat`/`less`/`cat` still show source with syntax
  highlighting; `md` shows rendered output. **`mdp` is `md -p`** — same render,
  through a pager (real `less`, not the shell `less` wrapper, since glow spawns
  the pager as a subprocess and shell functions don't apply across that
  boundary). The alias passes `--style` directly rather than relying on
  `glow.yml` because glow on macOS reads its yml from
  `~/Library/Preferences/glow/`, not `~/.config/glow/`. Don't swap to `mdcat`,
  `frogmouth`, or another renderer without an explicit ask. (`mdcat` was
  considered and ruled out: archived upstream as of 2025-01-10.)

## Where things live

- Sources: `$PROJECTS_HOME/dotfiles/{.config,.vimrc,.vim/colors,.zshrc,.p10k.zsh,.claude/CLAUDE.md}` (`.config/` includes `nvim/`, `worktrunk/`, `glow/`)
- Targets: `~/.config/{ghostty,tmux,ccstatusline,nvim,worktrunk,glow}`, `~/.vimrc`, `~/.vim/colors`, `~/.zshrc`, `~/.p10k.zsh`, `~/.claude/CLAUDE.md`
- The repo's `.claude/CLAUDE.md` IS the user-global Claude config (symlinked to `~/.claude/CLAUDE.md`). Edits there apply to every project on this machine, not just dotfiles.
- Machine-specific overrides: `~/.zshrc.local` (untracked; copy from `.zshrc.local.template`)
- Helpers: `.config/tmux/bin/tmux-{project-name,git-status}`
- Smoke tests for helpers: `scripts/test-helpers.sh`

## Cheatsheets (`docs/`)

Three standalone HTML reference pages live in `docs/` — Solarized-styled, print-friendly,
generated by hand from the live config and pinned to today's setup:

- `docs/nvim-cheatsheet.html` — LazyVim leader map, picker, LSP, neotest, Mason/Lazy
- `docs/shell-colors-cheatsheet.html` — eza, bat, less wrapper, git-delta, glow/`md`,
  vivid, fzf, zsh-autosuggestions / zsh-syntax-highlighting plus aliases
- `docs/tmux-cheatsheet.html` — prefix `C-a` map, sessions/windows/panes, sesh picker
  (`<prefix> t`), hand-rolled status bar, copy mode

**Update the relevant sheet whenever the underlying config drifts** — new aliases in
`.zshrc`, new keybindings in `tmux.conf`, plugin/extra changes in `~/.config/nvim/`,
swapped tools, etc. Each footer is dated; refresh that date when content is touched.
The sheets are committed (not gitignored) so anyone cloning the repo gets the same
reference; open them locally with `open docs/<name>.html`.

## Verify changes

- Helper smoke tests: `scripts/test-helpers.sh`
- Zsh prompt-context tests: `scripts/test-prompt-context.zsh`
- Tmux window-label tests: `scripts/test-tmux-window-label.zsh`
- Reapply symlinks (idempotent): `$PROJECTS_HOME/dotfiles/bootstrap.sh`
- Check brew deps without installing: `brew bundle check --file=$PROJECTS_HOME/dotfiles/Brewfile --verbose`
- nvim plugin smoke test: `scripts/test-nvim.sh`

## First-time setup on a new machine

After `brew bundle` and `bootstrap.sh`, run once to wire git → delta:

```bash
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.syntax-theme "Solarized (dark)"
```

## Out of scope (future work, separate spec)

- Lifting API tokens out of `~/.zshrc` into `~/.secrets`
- tmux ↔ `EnterWorktree` auto-window integration
