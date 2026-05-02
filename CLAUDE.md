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
- **tmux URL picker is `<prefix> u` via a thin wrapper over `tmux-fzf-url`**
  (`.config/tmux/bin/tmux-fzf-url-newest`). The plugin
  (`wfxr/tmux-fzf-url`, loaded by TPM) supplies the `xre` regex binary,
  pattern set, `fzf_filter`, and `open_url` helpers; the wrapper sources
  `fzf-url.sh` with its test guard tripped (`__FZF_URL_TESTING=1`) to
  import those, then captures the current pane's full 50000-line
  scrollback, reverses it with `tail -r` (BSD; macOS native — no
  coreutils dependency, so don't swap to `tac`) so `xre`'s
  first-appearance dedup keeps the LATEST occurrence of each URL, and
  pipes through the plugin's helpers unchanged. Popup geometry:
  `-w 70% -h 70%`. Width (70%) matches the sesh and file pickers — the
  shared anchor across the three pickers. The sesh picker's height is
  now dynamic (see the sesh bullet); URL height stays fixed because
  scrollback URLs aren't a countable list. `--tac` in
  `@fzf-url-fzf-options` is intentional so the newest URL lands at the
  cursor — don't drop it.
  The wrapper owns the binding (added after the TPM `run` line in
  `tmux.conf`); don't remove the wrapper either (without it the
  plugin's binding wins and recurring URLs sort to oldest position).
  Don't replace the wrapper with a fully custom shell script; regex
  extraction still goes through the plugin's `xre`.
- **`<prefix> o` is the file-picker binding** (sibling of `<prefix> u` URL
  picker). Implemented by `.config/tmux/bin/tmux-fzf-file` (picker) +
  `tmux-open-in-nvim` (dispatcher). nvim auto-listens on
  `$XDG_RUNTIME_DIR/nvim-tmux-<session>.sock` from
  `lua/config/options.lua`. Don't replace with `<prefix> f` (used by other
  tmux plugins as "next session") or `<prefix> p` (used for paste-buffer in
  copy-mode).
- **OSC 8 hyperlinks pass through tmux to Ghostty.** Two `terminal-features`
  declarations in `.config/tmux/tmux.conf` (`xterm-ghostty:hyperlinks` and
  `xterm-256color:hyperlinks`) enable hyperlink passthrough; without them
  tmux strips OSC 8 sequences and Claude Code's file-reference links don't
  render. Don't remove. Routing of `file://` clicks is handled by the user's
  existing macOS file-type defaults — the repo deliberately ships no `duti`
  config, no Claude Code setting override, no Ghostty `link` rule. If the
  user wants VS Code (or another editor) for a given extension, they set it
  via Finder → Get Info → Open with → Change All.
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
  `sesh picker -i -d -H -c -t -T` — three sources only (configured /
  tmux / tmuxinator). The binding is
  `run -b ~/.config/tmux/bin/tmux-sesh-picker` (not inline
  `display-popup`): the wrapper counts entries via
  `sesh list -d -H -c -t -T` (mirrors the picker's flag set), then opens
  `display-popup -E -w 70% -h "$H"` where
  `H = items + 11` (sesh chrome 9 + tmux popup border 2), clamped
  to `[12, 80% of client height]` (fallback `15` if `sesh list`
  fails). Width stays at 70% — shared anchor with the URL and
  file pickers; height is dynamic. Don't fold the wrapper back
  inline — recomputing the height per keypress requires a real
  script. Zoxide is intentionally **not** a picker source:
  the `-c -t -T` flags are inclusive opt-in, so omitting `-z` drops
  zoxide. Don't re-introduce a custom fzf wrapper script. Zoxide is
  still loaded for `z`-cd, and `_ZO_EXCLUDE_DIRS` blocks `~/`,
  `~/Downloads/*`, `~/.config/*`, `~/Library/*` from being indexed —
  keeps `z lib`/`z config`/etc. from jumping into noise dirs.
- **`s` is the worktree+session command** (`bin/s`, symlinked to
  `~/.local/bin/s` by `bootstrap.sh`). Surface:
  `s [<project>] [<name>]`. Inside tmux a single arg is the worktree
  name (project inferred from cwd's main worktree); outside tmux a
  single arg is a project name (no worktree, attaches to project's
  main session). Two args are always `<project> <worktree-name>`.
  Tmux session naming uses `/` as separator (`<project>/<name>`)
  because tmux disallows `:` and `.`. The branch name is used
  verbatim — `s` does **not** apply the `worktree-` prefix; that
  prefix is reserved for the `EnterWorktree` Claude Code workflow.
  Project list comes from `sesh list -c -j` (the configured-sessions
  source); no separate registry. Don't wrap `<prefix> t` to add
  create-on-miss — the picker stays vanilla per the existing house
  rule.
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
  When a Claude Code session is active in the pane,
  `@claude_session_name` overrides `@last_cmd` and the window renders
  `claude[<name>]`. Set/cleared by `~/.config/tmux/bin/claude-tmux-window-name`
  via Claude Code hooks (`SessionStart`, `Stop`, `SessionEnd`) wired in
  `~/.claude/settings.json`. The hook config is per-machine (not symlinked
  from this repo — see [`README.md`](README.md) → "Setup (new machine)"). The script's
  test mock and the script itself live separately —
  `scripts/test-claude-tmux-window-name.zsh` exercises the script through a
  temp `$HOME` and a `tmux` PATH shim, so no in-place duplication of logic.
- **Bells are silenced at every layer** (Ghostty `bell-features =`, zsh
  `unsetopt BEEP/HIST_BEEP/LIST_BEEP`, vim `belloff=all`, tmux
  `bell-action/visual-bell/monitor-bell off`). Don't re-enable without
  an explicit ask.
- **Shell colors are Solarized Dark, end-to-end.** Tools: `eza` (ls),
  `bat` (cat + `MANPAGER`), `git-delta` (git pager), `glow` (`md` markdown
  renderer), `vivid` (`LS_COLORS`), `procs` (`ps` replacement),
  `zsh-syntax-highlighting`, `zsh-autosuggestions`, `fzf-tab` (Tab completion
  picker). Palette pins:
  `vivid generate solarized-dark`, `bat --theme="Solarized (dark)"`,
  `delta.syntax-theme = "Solarized (dark)"`, `procs` reads
  `.config/procs/procs.toml` (Pid=violet, User=blue, percentage gradient
  blue→green→yellow→red),
  `md` alias passes `--style .config/glow/glamour.json` (chroma
  `solarized-dark` for fenced code blocks). Don't swap themes or
  introduce alternatives (`exa`, `lsd`, `diff-so-fancy`, `mdcat`, etc.)
  without asking. Plugin source order in `.zshrc` is fixed: fzf →
  `bindkey -r '^[c'` (Alt-C unbind) → zoxide → fzf-tab →
  zsh-autosuggestions → zsh-syntax-highlighting (must be last).
  fzf-tab needs fzf's `^I` binding already in place and must be sourced
  before any plugin that wraps widgets. The first-time `git config`
  recipe wiring delta as git's pager
  lives in [`README.md`](README.md) → "Setup (new machine)".
- **`ps` is aliased to `procs`** (modern ps replacement; Rust). Two
  Solarized-themed configs live in `.config/procs/`: `procs.toml` (default,
  PID asc, ps-like columns) is read by bare `procs` / `ps`;
  `procs-heavy.toml` (UsageCpu desc, trimmed columns
  `Pid User UsageCpu UsageMem VmRss Command`) is loaded by the `psh` alias
  via `--load-config`. The two TOMLs duplicate their `[style.*]` blocks on
  purpose — `procs --load-config` replaces the entire config (no
  inheritance), so style edits must touch both files. Aliases are guarded
  on `command -v procs`. Escape hatches: `command ps`, `\ps`, `/bin/ps`
  reach legacy `ps`; non-interactive shells (scripts) never see the alias.
  macOS caveat: `procs` only shows the current user's processes even with
  no filter (Apple gates cross-user visibility behind elevated privileges);
  for "show all system daemons" use `\ps -ax`. Don't add a `psx` alias for
  the all-users view — legacy `ps` already serves it without a sudo prompt.
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
- **`top` is a zsh alias to `btop`** (defined in `.zshrc`, guarded on
  `command -v btop`). Theme is pinned `solarized_dark` via
  `.config/btop/btop.conf` (only `color_theme`,
  `theme_background = False`, and `vim_keys = True` are pinned —
  everything else rides btop defaults). macOS `top` is reachable via
  `command top` or `\top`. Don't replace btop with htop or vendor a
  custom Solarized theme file — `solarized_dark` is built-in. Don't
  pin more keys without a clear reason — small diff = easy upstream
  bumps.
- **`diff` is a zsh alias to `difft`** (defined in `.zshrc`, guarded on
  `command -v difft`). Difftastic is a syntactic, language-aware diff for
  ad-hoc, non-git file comparisons. Git diffs are unaffected — git's pager
  is still `delta`, and that wiring is intentional. `vimdiff` is also
  unaffected — it's a separate alias (`vim -d`, which resolves via the
  `vim`→`nvim` alias). Escape hatches: `command diff`, `\diff`,
  `/usr/bin/diff` reach legacy `diff`. Non-interactive shells (scripts,
  Make, CI) never see the alias. Don't pin flags on the alias —
  difftastic's defaults (`--background dark`, side-by-side, color auto)
  already match the Solarized Dark setup; the terminal palette supplies
  the colors.

## Where things live

- Sources: `$PROJECTS_HOME/dotfiles/{.config,.vimrc,.vim/colors,.zshrc,.p10k.zsh,.claude/CLAUDE.md}` (`.config/` includes `nvim/`, `worktrunk/`, `glow/`)
- Targets: `~/.config/{ghostty,tmux,ccstatusline,nvim,worktrunk,glow}`, `~/.config/sesh/sesh.toml`, `~/.local/bin/<command>`, `~/.vimrc`, `~/.vim/colors`, `~/.zshrc`, `~/.p10k.zsh`, `~/.claude/CLAUDE.md`
- The repo's `.claude/CLAUDE.md` IS the user-global Claude config (symlinked to `~/.claude/CLAUDE.md`). Edits there apply to every project on this machine, not just dotfiles.
- Machine-specific overrides: `~/.zshrc.local` (untracked; copy from `.zshrc.local.template`)
- Helpers: `.config/tmux/bin/{tmux-project-name,tmux-git-status,claude-tmux-window-name,tmux-fzf-file,tmux-open-in-nvim}`
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

Shared styles (Solarized palette, base typography, kbd/code/grid/card/footer/
print rules) live in `docs/style.css`; each cheatsheet's residual inline
`<style>` block holds only page-specific rules. When editing a cheatsheet,
prefer adding new shared rules to `docs/style.css` rather than re-inlining.
A landing page at `docs/index.html` lists the three cheatsheets and is
served at `https://martinciu.github.io/dotfiles/` via GitHub Pages
(source: `main`, folder `/docs`, with a `docs/.nojekyll` marker).

## Verify changes

- Helper smoke tests: `scripts/test-helpers.sh`
- File-picker path-extraction tests: `scripts/test-fzf-file-extract.sh`
- Zsh prompt-context tests: `scripts/test-prompt-context.zsh`
- Tmux window-label tests: `scripts/test-tmux-window-label.zsh`
- Claude tmux window-name tests: `scripts/test-claude-tmux-window-name.zsh`
- URL-picker wrapper tests: `scripts/test-tmux-fzf-url-newest.sh`
- Session-root binding tests: `scripts/test-s-session-root.sh`
- Reapply symlinks (idempotent): `$PROJECTS_HOME/dotfiles/bootstrap.sh`
- Check brew deps without installing: `brew bundle check --file=$PROJECTS_HOME/dotfiles/Brewfile --verbose`
- nvim plugin smoke test: `scripts/test-nvim.sh`

## First-time setup on a new machine

See [`README.md`](README.md) → "Setup (new machine)".
