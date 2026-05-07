# dotfiles — Claude Code instructions

Personal Solarized + JetBrainsMono Nerd Font setup for Ghostty + tmux + vim + fish.

## Conventions — don't drift from these

- **Manual symlinks via `bootstrap.sh`.** No `stow`/`chezmoi`/etc.
- **Bash scripts target bash 5.** Shebang `#!/opt/homebrew/bin/bash`; may
  use `mapfile`, `declare -A`, `wait -n`. Apple Silicon only — `brew
  bundle` runs before `bootstrap.sh`. Don't reintroduce bash-3 shims.
- **Fish module layout.** Fish is the primary interactive shell. Config
  in `.config/fish/`, symlinked to `~/.config/fish`.
  `config.fish` is empty; concerns in `conf.d/<NN>-<concern>.fish`,
  numeric prefix pins load order:
  `00-env`, `10-colors`, `15-local` (per-machine, untracked), `20-mise`,
  `25-prompt` (starship), `30-aliases`,
  `35-abbreviations` (git-flow mnemonic abbrs — `gst`, `gco`, `gp`, …),
  `40-plugins` (fzf, zoxide, wt, Polish-diacritic Alt-C unbind),
  `50-tmux-hooks` (fish_preexec → `@last_cmd` per-pane stamp),
  `99-secrets` (untracked). The two untracked files are copied from
  `.template` companions by `bootstrap.sh`. `functions/less.fish`
  mirrors the zsh bat-backed `less`; `completions/wt.fish` adds wt
  tab-completion. Don't port `modern-reminder` to fish without an ask.
  Smoke test: `scripts/test-fish-loads.sh`.
- **Zsh module layout (fallback).** Fallback shell. Kept until the fish
  transition settles; see `REMOVAL.md` for the removal procedure. Don't
  add new functionality here — port to fish first. `.zshrc` is a thin
  orchestrator (~20 lines: `compinit`, one `source` per module,
  `~/.zshrc.local`, `~/.secrets`). Concerns live in
  `.config/zsh/<concern>.zsh`:
  - `env.zsh` — locale, EDITOR, PATH, MANPAGER, no-bells, emacs keys, history, shopts
  - `colors.zsh` — vivid `LS_COLORS`, fzf palette, autosuggest highlight
  - `mise.zsh` — `mise activate` chpwd hook
  - `tmux-hooks.zsh` — window-label, ssh-target
  - `modern-reminder.zsh` — default→modern tool nudge
  - `prompt.zsh` — Starship init
  - `aliases.zsh` — color-aware aliases + bat-backed `less()`
  - `plugins.zsh` — fzf, zoxide, fzf-tab, wt, autosuggestions, syntax-highlighting (order-critical; header docs it)

  Shape: defs on top, side-effects guarded by
  `[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return` so tests source modules
  without firing hooks. `~/.zshrc.local` sources between `colors.zsh` and
  `mise.zsh` — after PATH appends, before hook-registering modules. New
  concerns get their own module file; don't add top-level `source` calls
  outside the `.config/zsh/` set.
- **`.zprofile` runs `brew shellenv`** (zsh-side login init; fish parity
  is in `.config/fish/conf.d/00-env.fish`) so `/opt/homebrew/bin` precedes
  the paths macOS's `/etc/zprofile` (`path_helper`) installs. Don't move
  into `.zshrc` — interactive subshells re-source it and re-stack PATH.
  Machine-specific login init that needs to run before `compinit` (e.g.
  OrbStack, anything doing `fpath+=`) goes in `~/.zprofile.local`
  (untracked; copy from template). `.zshrc.local` is sourced *after*
  `compinit`, so late `fpath+=` silently no-ops there.
- **`Brewfile` is installed by bootstrap.** `bootstrap.sh` runs
  `brew bundle --file=$DOTFILES/Brewfile` unconditionally at the top,
  before any symlinks. Aborts on failure (`set -euo pipefail`).
- **Global gitignore is symlinked from `.gitignore_global`.**
  `bootstrap.sh` links it to `~/.gitignore_global` (the path
  `core.excludesfile` already points to). Lists the cross-repo
  never-commit set: Claude Code state (`settings.local.json`,
  `todos.json`, `worktrees/`, `logs/`, `.credentials.json`), planning
  artefacts (`.superpowers/`, `.autonomo/`). Don't add language patterns
  (e.g. `node_modules/`) — those belong in per-language `.gitignore`.
- **tmux status bar is hand-rolled** in `.config/tmux/tmux.conf` with
  Solarized base16. No theme plugins (catppuccin, tmux-powerline, etc.).
  Each status-bar **pin** uses a unique Solarized accent. Currently:
  blue (session chip, left), green (active window pin, center), violet
  (main-checkout git chip), yellow (worktree git chip), orange (PR pin,
  left of git chip). When adding a pin, pick from unused accents (red,
  magenta, cyan); reconsider if all are taken. Mode-style, message-style,
  pane-borders, and inline text colors (e.g. ins/del markers in
  `tmux-git-status`) are not pins.
- **SSH indicator on the session chip** via
  `#(~/.config/tmux/bin/tmux-ssh-indicator)`. Walks each attached
  client's parent-process chain via `ps -p <pid> -o ppid=,ucomm=`,
  emits Nerd Font globe (U+F0AC) when an ancestor is `sshd`/`sshd-session`.
  **Use `ucomm`, not `comm`** — `ps -o comm=` for sshd's privsep
  children renders the argv string and never basename-matches.
  Server-wide; refresh piggybacks on the 5 s `status-interval`. Mosh
  not detected (add `mosh-server` to match if needed). `$SSH_CONNECTION`
  intentionally unused (set in the SSH-spawned shell, not the tmux server).
- **tmux PR pin** wired into `status-right` via
  `#(~/.config/tmux/bin/tmux-status-right #{pane_current_path})`. Calls
  `tmux-pr-detect` (stale-while-revalidate cache around `gh pr view`,
  TTL 60 s, at `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-pr-pin/<repo>-<branch>`).
  When a PR exists (OPEN or DRAFT — single visual), an orange chip
  (`#cb4b16`) renders ` #<num>` (U+F407); `tmux-git-status` is called
  with `prev_bg=#cb4b16` so its `tri_l` becomes the yellow-on-orange
  separator. `<prefix> P` opens via `gh pr view --web`. Cache key uses
  `git-common-dir` so worktrees share per-branch entries. First call
  after branch switch shows nothing; next 5 s tick renders — accepted
  to never block on a slow `gh`.
- **Outbound SSH overlay on the Ghostty tab title.** While `ssh` is
  foreground, the tab renders ` user@host`; otherwise
  `<session>:<window>`. Wired via `set-titles on` + a `set-titles-string`
  branching on per-pane `@ssh_target`. `_tmux_record_ssh_target`
  (preexec) checks first-token equality with `ssh` (excludes
  `ssh-add`/`ssh-keygen`), resolves via `ssh -G` so `~/.ssh/config`
  aliases canonicalize. `_tmux_clear_ssh_target` (precmd) unsets on
  next prompt; both call `tmux refresh-client -S`. Per-pane. Bodies
  in `.config/zsh/tmux-hooks.zsh`. Ctrl-Z'd `ssh` clears on next
  prompt (acceptable); nested `ssh` not tracked. Don't replace
  `ssh -G` with argv parsing.
- **tmux prefix is `C-a`** (`C-Space` conflicts with macOS input-source
  switching). Pane nav: `<prefix> h/j/k/l` (Alt is reserved for Polish
  diacritics — never `bind -n M-*`). Splits: `|` and `-`.
- **TPM is the tmux plugin manager.** Loaded: `tmux-sensible`,
  `tmux-resurrect`, `tmux-continuum` (`@continuum-restore 'on'`),
  `tmux-sessionx`. Status bar is hand-rolled, behavior plugins aren't —
  don't remove TPM.
- **OSC 8 hyperlinks pass through tmux.** Two `terminal-features`
  entries (`xterm-ghostty:hyperlinks`, `xterm-256color:hyperlinks`).
  Without them, tmux strips OSC 8 and Claude Code's file-ref links don't
  render. `file://` click routing: macOS file-type defaults — no `duti`,
  no Ghostty `link` rule.
- **Sesh config is split: shared + machine-local.** Repo tracks
  `.config/sesh/sesh.toml` (a `Home 🏠` session for `~` plus
  `import = ["~/.config/sesh/sesh.local.toml"]`). Machine-local sessions
  go in the local file (untracked, copied from template by
  `bootstrap.sh`). Don't add machine-specific entries to the shared
  file; don't drop the `import` line — sesh hard-errors on missing
  imports. Sesh is no longer the picker (only `bin/s`'s registry);
  picker is `tmux-sessionx`.
- **tmux-sessionx is the session picker** (`<prefix> t`; default
  clock-mode moved to `<prefix> T`). Loaded via TPM (`omerxx/tmux-sessionx`);
  binding claimed by `@sessionx-bind 't'`. Geometry pinned `70% × 70%`.
  Sources: tmux + tmuxinator (`@sessionx-tmuxinator-mode 'on'`); zoxide
  off (`@sessionx-zoxide-mode 'off'`, set explicitly so the rule is
  visible). `@sessionx-filter-current 'true'`. Preview is sessionx
  default (`tmux capture-pane -ep`); `preview.sh` hardcoded inside the
  plugin, no override hook. Zoxide still loaded for `z`-cd;
  `_ZO_EXCLUDE_DIRS` blocks `~/`, `~/Downloads/*`, `~/.config/*`,
  `~/Library/*`.
- **`s` is the worktree+session command** (`bin/s` → `~/.local/bin/s`).
  Surface: `s [<project>] [<name>]`. Inside tmux, single arg = worktree
  name (project inferred from cwd's main worktree); outside tmux,
  single arg = project name. Two args = `<project> <name>`. Session
  naming uses `/` (tmux disallows `:`/`.`). Branch name is verbatim —
  `s` does **not** apply `worktree-`; that's reserved for `EnterWorktree`.
  Project list from `sesh list -c -j`. Fish completions live in
  `.config/fish/completions/s.fish`: pos 1 (outside tmux) suggests
  sesh project names, pos 1 (inside tmux) and pos 2 suggest existing
  *secondary* worktree branches via `git worktree list --porcelain`
  (the primary checkout's branch is filtered out by path comparison).
  Completions are non-exclusive — typing a fresh name still creates
  a new worktree.
- **`dashboard` is the multi-session live preview command**
  (`bin/dashboard`, symlinked to `~/.local/bin/dashboard`). Surface:
  `dashboard <pattern> [--cols N]`, plus internal
  `--page-down`/`--page-up`/`--rebuild`. Spawns/rebuilds a
  `dashboard-<derived>` session with one polled `watch + capture-pane`
  tile per matched session (excluding `dashboard-*`). Prefix uses `-`
  not `:` (tmux rewrites `:`). `<prefix> J/K` page rows; no-ops outside
  `dashboard-*`. Bindings pass `DASHBOARD_TARGET=#{session_name}` —
  `display-message -p '#S'` in `run-shell` returns the global
  most-recent session, not the run-shell target. `--cols N` forces an
  N-column grid via two-pass split; otherwise tmux's `tiled` is used.
  Don't replace polling with `link-window` or nested `tmux attach`.
  Reads `$TMUX_SOCKET` (test-mode isolation) and `$DASHBOARD_NO_FINISH`
  (skip final attach — used by integration tests).
- **`vim`/`vimdiff` are zsh aliases to nvim**; **`vi` is `command vim`**
  (legacy minimal vim). All guarded on `command -v nvim`. Minimal vim
  (`.vimrc` ~30 lines, `.vim/colors/solarized8.vim`) is reachable via
  `vi`/`command vim`/`\vim`. Don't add vim-plug or LSP to it.
- **nvim is built on LazyVim**, themed Solarized, configured at
  `.config/nvim/`. Don't replace LazyVim.
- **LazyVim Alt-keymaps removed** in `lua/config/keymaps.lua`
  (`<A-j>/<A-k>`) — Alt is reserved for Polish diacritics. Don't re-add.
- **LSPs off by default in nvim.** `lua/plugins/lsp-disable-all.lua`
  sets `enabled = false, mason = false` on every LazyVim-core/extra
  server (`lua_ls`, `jsonls`, `marksman`, `vtsls`, `ts_ls`,
  `tailwindcss`, `yamlls`, `eslint`, `ruby_lsp`, `rubocop`). Mason
  packages stay installed for instant opt-in. Per-session:
  `:LspOn <name>` (user command, wraps `vim.lsp.enable`). Per-project:
  drop a `.nvim.lua` with `vim.lsp.enable({...})` — requires
  `vim.o.exrc = true` (not set). Why off: first-attach blocks the UI
  3-6 s+; dotfiles editing rarely needs gd/hover/rename. The
  `VimLeavePre` autocmd in `lua/config/autocmds.lua` force-stops LSP
  clients on exit so libuv handles drain — without it opt-in projects
  leak handles and leave stale swap files. New LazyVim servers:
  append to the list.
- **No schemastore catalog injection for jsonls/yamlls.**
  `lua/plugins/lsp-no-schema-fetch.lua` overrides LazyVim's
  `before_init` with a no-op so the ~700-entry catalog is never written
  to `settings.{json,yaml}.schemas`. Each pattern match would trigger
  an HTTP fetch — freeze risk on flaky networks. Inline `$schema` URLs
  still resolve. Keep separate from `lsp-disable-all.lua` (different
  concern).
- **Mason-managed LSPs are pinned** via `mason-lock.json` (committed).
  `:MasonLock` snapshots; `:MasonLockUpdate` upgrades then snapshots.
  `lazy-lock.json` and `mason-lock.json` both committed.
- **Solarized + JetBrainsMono Nerd Font everywhere — except the starship
  prompt.** Every other tool stays Solarized Dark. Starship uses a
  single pastel rose accent (`#DA627D`) in `[palettes.solarized_dark]`
  of `.config/starship.toml`. Chip is flush-left, ends with U+E0B4
  rounded right cap; prompt char drops to line 2. Single chip because
  starship silently drops `bg:` when both `fg:` and `bg:` reference
  custom palette names in the top-level format. Don't extend pastel to
  other tools; don't add `(fg:custom_a bg:custom_b)` chips.

  Fish (primary) opts into Starship's transient prompt; zsh (fallback)
  does not — don't add it to zsh. After Enter, fish replaces the active
  chip with a bold `❯`; `cmd_duration`/`status` stay intact. Wired via
  `enable_transience` from `.config/fish/conf.d/25-prompt.fish`. Starship
  1.25.x has no `[transient_prompt]` section — don't add one (silently
  ignored, trips `[WARN]`).
- **wt user config is symlinked from `.config/worktrunk/config.toml`.**
  Per-project `approvals.toml` is machine-local and gitignored.
- **Gitignored content flows between primary and worktrees in two
  stages**, both using `wt step copy-ignored`. `[post-start] copy`
  reflinks primary's ignored content into a new worktree at creation;
  `[pre-remove] save-shared` reflinks back just before `wt remove`.
  Default no-`--force` on both — destination files are never
  overwritten. Auto-discovers any new gitignored top-level dir.
  Caveat: `step.copy-ignored.exclude` is shared across directions, so
  derived-state dirs (`node_modules/`, `target/`) carried in also flow
  back if mutated. Don't reintroduce per-path symlink hooks (the old
  `share-tmp` design).
- **Worktree status segment** uses `git rev-parse --git-dir` vs
  `--git-common-dir` for detection. Don't replace with
  `git worktree list` parsing.
- **tmux window name follows the active pane's last typed command.**
  Both shells set per-pane `@last_cmd` from preexec hooks
  (`.config/zsh/tmux-hooks.zsh`, `.config/fish/conf.d/50-tmux-hooks.fish`).
  `tmux.conf` enables `automatic-rename` reading it. Env-var assignments
  stripped; first two whitespace tokens used. `allow-rename off` stays
  so OSC titles can't override. Tests source modules under
  `*_DOTFILES_TEST=1` and run the same 11-case matrix.

  Claude Code is not specially handled — interactive-shell launches
  stamp `@last_cmd=claude`. Caveat: panes that bypass the shell
  (`tmux new-window 'claude'`, sesh/tmuxinator `command = "claude"`)
  have no preexec stamp, so the window falls back to
  `#{pane_current_command}` — for Claude Code that's the version
  string (e.g. `2.1.131`) because the binary lives at
  `~/.local/share/claude/versions/<X.Y.Z>` and `comm` records the
  resolved-symlink basename. Fix on the launch-config side.
  `~/.config/tmux/bin/claude-tmux-window-name` and its
  `SessionStart`/`Stop`/`SessionEnd` hooks survive: `set` mode dormant
  (Claude Code dropped session JSON `.name` ~2.1.126), but `clear`
  mode unsets `@last_cmd` on `SessionEnd` so the window flips back
  promptly. Hook config is per-machine (not symlinked — see README).
- **Bells silenced at every layer:** Ghostty `bell-features =`, zsh
  `unsetopt BEEP/HIST_BEEP/LIST_BEEP`, vim `belloff=all`, tmux
  `bell-action/visual-bell/monitor-bell off`. Fish has no BEEP option;
  any `\a` is consumed at Ghostty/tmux. Don't re-enable.
- **Terminal tools are Solarized Dark, end-to-end.** `eza`, `bat`,
  `git-delta`, `glow` (`md`), `vivid` (`LS_COLORS`), `procs` (`ps`),
  `tailspin` (`tspin`), `xh`, `zsh-syntax-highlighting`,
  `zsh-autosuggestions`, `fzf-tab`. Pins: `vivid generate solarized-dark`,
  `bat --theme="Solarized (dark)"`, `delta.syntax-theme = "Solarized (dark)"`,
  `procs` reads `.config/procs/procs.toml`, `md` passes
  `--style .config/glow/glamour.json`, `tspin` reads
  `.config/tailspin/theme.toml` (ANSI names; severity keywords
  `error`/`warn`/`info`/`debug` as `[[keywords]]`). No `tail` alias —
  `tspin file.log` / `cmd | tspin -p` stay explicit. Don't introduce
  alternatives (`exa`, `lsd`, `diff-so-fancy`, `mdcat`).

  Plugin source order in `.config/zsh/plugins.zsh` is fixed: fzf →
  `bindkey -r '^[c'` (Alt-C unbind) → zoxide → fzf-tab →
  zsh-autosuggestions → zsh-syntax-highlighting (must be last). fzf-tab
  needs fzf's `^I` binding and must precede widget-wrapping plugins.
  First-time `git config` for delta is in README → "Setup".
- **`ps` aliased to `procs`.** Two configs in `.config/procs/`:
  `procs.toml` (default, PID asc) read by bare `procs`/`ps`;
  `procs-heavy.toml` (UsageCpu desc, trimmed columns) loaded by `psh`
  via `--load-config`. Both duplicate `[style.*]` blocks because
  `--load-config` replaces the entire config (no inheritance). Aliases
  guarded on `command -v procs`. Escape: `command ps`, `\ps`,
  `/bin/ps`. macOS shows only the current user's processes; for all,
  `\ps -ax`. No `psx` alias — legacy `ps` already serves it.
- **Interactive `less` is a `bat` wrapper** (in
  `.config/zsh/aliases.zsh`). Files get bat decoration; piped input
  uses `--plain` (so stdin doesn't get bat's `STDIN` header).
  `command less` reaches real `less` for `+F`/`-R`/etc. Don't
  `alias less='bat …'` and don't set `$PAGER=bat` globally.
- **`md` renders markdown via `glow`**, style at
  `.config/glow/glamour.json`. **`mdp` is `md -p`** — same render
  through real `less` (glow spawns the pager as a subprocess; the
  `less` wrapper doesn't apply). Alias passes `--style` directly
  because glow on macOS reads its yml from
  `~/Library/Preferences/glow/`, not `~/.config/glow/`. Don't swap to
  `mdcat`/`frogmouth` (`mdcat` archived 2025-01-10).
- **`top` aliased to `btop`** (guarded). Theme `solarized_dark` via
  `.config/btop/btop.conf` (only `color_theme`, `theme_background = False`,
  `vim_keys = True` pinned). macOS `top` reachable via `command top`.
  `solarized_dark` is built-in; don't vendor a custom theme.
- **`lnav` is the TUI log navigator** (raw command, no alias). Only
  `installed/` subdirs are symlinked — `bootstrap.sh` creates
  `~/.config/lnav/` as a real dir, then links
  `~/.config/lnav/{configs,formats}/installed` into the repo. lnav owns
  the rest (samples, `crash/`, `staging/`, `log_metadata.db`,
  `view-info-*.json`, `config.json`). Don't re-introduce a whole-dir
  symlink (issue #64). Theme is built-in `solarized-dark`, activated by
  `solarized-dark.json` (sets `ui.theme`). Custom formats in
  `.config/lnav/formats/installed/<name>.json`; one tracked:
  `inngest.json` for `inngest-cli dev` JSON-per-line stdout. `lnav -i`
  writes into `installed/` and therefore the repo (intended).
- **`diff` aliased to `difft`** (guarded). For ad-hoc, non-git
  comparisons. Git diffs unaffected (still `delta`); `vimdiff`
  unaffected (separate alias). Escape: `command diff`, `\diff`,
  `/usr/bin/diff`. Don't pin flags.
- **`xh` is the interactive HTTP client** (HTTPie-compatible). `xh`
  (HTTP-default), `xhs` (HTTPS-default). Theme pinned via
  `.config/xh/config.json` (`{"default_options": ["--style=solarized"]}`).
  **Don't alias `curl` to `xh`** — `curl` stays for scripts/CI. No
  `http`/`https` alias either ("no synonyms").
- **`hyperfine` is the benchmark tool, additive to `time`** (raw, no
  alias). `time` for one-shot wall-clock; `hyperfine` for warmups,
  multiple runs, A/B. **Deliberately NOT in modern-reminder** — not a
  1:1 swap (different use cases). Don't alias or wrap.
- **`duf` is a modern `df` companion** (raw, no alias). Grouped output by
  device class (local/network/special/fuse), color-coded usage bars, theme-
  aware (auto-detects dark; `--theme dark` pins it). `df` stays for scripts
  and POSIX habit; `duf` for interactive disk-free checks. **Deliberately
  NOT added to modern-reminder** — that system is deprecated alongside zsh
  (see `REMOVAL.md` §1 row 2). Don't alias or wrap.
- **`dust` is a modern `du` companion** (raw, no alias). Tree-style output
  sorted largest-first, colored bar graphs per node, depth-aware (`-d N`
  to limit). Read-only inspection — fast parallel scan, zero side effects.
  `du` stays for scripts and POSIX habit; `dust` for "where did my disk
  go?" at-a-glance. **Deliberately NOT added to modern-reminder** — that
  system is deprecated alongside zsh (see `REMOVAL.md` §1 row 2). Don't
  alias or wrap.
- **`dua` is a fast `du` aggregate with an interactive TUI deleter** (raw,
  no alias). Plain `dua [path]` walks the tree in parallel and prints
  aggregate sizes; `dua i [path]` opens a TUI for navigating, marking, and
  *deleting* directories. `du` stays for scripts and POSIX habit; `dua`
  for fast aggregates and interactive disk reclaim. **Deliberately NOT
  added to modern-reminder** — that system is deprecated alongside zsh
  (see `REMOVAL.md` §1 row 2). Don't alias or wrap.
- **`tealdeer` (`tldr`) is a modern `man` supplement** (raw, no alias).
  Community-curated example pages cached locally; `.config/tealdeer/config.toml`
  pins `[updates] auto_update = true` with a 720h (30-day) refresh interval —
  the first `tldr <cmd>` after the interval lazily fetches. Pairs with
  bat-paged `man` (see `MANPAGER` in `conf.d/00-env.fish`): `man` for full
  manuals, `tldr` for "show me the common flags". Theming uses **named ANSI
  colors** (`"blue"`/`"green"`/`"yellow"`) in tealdeer's `[style]` block —
  tealdeer 1.8.x doesn't accept hex; the Solarized translation comes from
  the terminal's 16-color palette (Ghostty + tmux), so `"blue"` renders as
  Solarized blue (#268bd2), `"green"` as Solarized green (#859900), etc.
  `"yellow"` stands in for orange (not in the named set) for
  `example_variable`. **macOS path quirk**: tealdeer's OS-convention config
  dir is `~/Library/Application Support/tealdeer/`; `TEALDEER_CONFIG_DIR`
  is set in `conf.d/00-env.fish` to redirect tealdeer to `~/.config/tealdeer/`,
  keeping the repo's `.config/<tool>/` source-of-truth shape. fish/zsh
  completion comes from the brew formula (`vendor_completions.d/` /
  `site-functions/`); no per-shell completion file in this repo. Brew
  formula doesn't ship a man page — `man tldr` will not resolve. **Deliberately
  NOT added to modern-reminder** — deprecated alongside zsh (see `REMOVAL.md`
  §1 row 2). Don't alias or wrap.
- **`modern-reminder` is a zsh discoverability nudge** for default→modern
  pairs left unaliased ("no synonyms" pattern: `tail`/`tspin`,
  `grep`/`rg`, `curl`/`xh`). Defined in
  `.config/zsh/modern-reminder.zsh` as `_modern_reminder_pairs` /
  `_modern_reminder_hints` plus a preexec (scan-all-tokens via `${(z)…}`,
  strip `\` and dirname) and precmd (once-per-shell seen set,
  `command -v` check, `print -P`). Hints embed Nerd Font glyphs as
  `\u…` and color via `%F{yellow}%f` so source stays 7-bit ASCII.
  **No backticks or `$(…)` in hints** — under `PROMPT_SUBST` (set by
  starship), `print -P` performs command substitution; use single
  quotes. Toggled by `export MODERN_REMINDER=1`. State is per-zsh-process.
  **When introducing a new modern tool under the "no synonyms" pattern**,
  evaluate against criteria (default in common interactive use; modern
  alternative installed and Solarized-themed; deliberately unaliased)
  and add to both arrays. Drop entries when a default gains an alias.

## Where things live

- Sources in `$PROJECTS_HOME/dotfiles/`: `.config/` (whole-dir per tool:
  `btop`, `ccstatusline`, `fish`, `ghostty`, `glow`, `nvim`, `procs`,
  `tailspin`, `tmux`, `worktrunk`, `xh`, `zsh`; plus `starship.toml`,
  partial links for `sesh/sesh.toml` and `lnav/{configs,formats}/installed`),
  `.vimrc`, `.vim/colors`, `.zshrc`, `.zprofile`, `.gitignore_global`,
  `.claude/CLAUDE.md`. `bin/` files symlink to `~/.local/bin/`.
- The repo's `.claude/CLAUDE.md` IS the user-global Claude config
  (symlinked to `~/.claude/CLAUDE.md`). Edits apply machine-wide.
- Machine overrides: `~/.zshrc.local`, `~/.zprofile.local` (untracked;
  copy from templates).
- Helpers: `.config/tmux/bin/{tmux-git-status,claude-tmux-window-name,tmux-ssh-indicator,tmux-pr-detect,tmux-status-right}`.

## Cheatsheets (`docs/`)

Three Solarized HTML reference pages, hand-generated:
`nvim-cheatsheet.html`, `terminal-cheatsheet.html`, `tmux-cheatsheet.html`.

**Update the relevant sheet whenever config drifts.** Each footer is
dated; refresh on touch. Open with `open docs/<name>.html`. Shared
styles in `docs/style.css`; prefer adding there over re-inlining.
Landing page `docs/index.html` is served at
`https://martinciu.github.io/dotfiles/` via GitHub Pages (source `main`,
folder `/docs`, `docs/.nojekyll`).

Sheets and README embed screenshots. Sources:
`docs/images/example_<tool>.png` (3176×1920, hand-captured). Derivatives
— `-hero.png` (1600px), `-thumb.png` (800px) — produced by
`scripts/build-screenshots.sh` (macOS `sips`). All three sizes committed;
re-run after swapping a source; never hand-edit derivatives. `<tool>`
is `tmux | vim | terminal` (note `example_vim.png` even though the sheet
is `nvim-cheatsheet.html`).

## Verify changes

- Helper smoke tests: `scripts/test-helpers.sh`
- Regenerate screenshots: `scripts/build-screenshots.sh`
- Tmux window-label (zsh): `scripts/test-tmux-window-label.zsh`
- Tmux window-label (fish): `scripts/test-fish-tmux-window-label.fish`
- Modern-reminder: `scripts/test-modern-reminder.zsh`
- Pre-remove save-shared: `scripts/test-wt-pre-remove-save.sh`
- Claude tmux window-name: `scripts/test-claude-tmux-window-name.zsh`
- tmux SSH-indicator: `scripts/test-tmux-ssh-indicator.sh`
- tmux PR-pin: `scripts/test-tmux-pr-status.sh`
- tmux SSH-target (outbound): `scripts/test-tmux-ssh-target.zsh`
- Session-root binding: `scripts/test-s-session-root.sh`
- Dashboard smoke + integration: `scripts/test-dashboard.sh`
- Fish config smoke: `scripts/test-fish-loads.sh`
- Reapply symlinks (idempotent): `$PROJECTS_HOME/dotfiles/bootstrap.sh`
- Brew deps (installed by bootstrap): `brew bundle check --file=$PROJECTS_HOME/dotfiles/Brewfile --verbose`
- nvim plugin smoke: `scripts/test-nvim.sh`

## First-time setup on a new machine

See [`README.md`](README.md) → "Setup (new machine)".
