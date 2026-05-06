# dotfiles — Claude Code instructions

Personal Solarized + JetBrainsMono Nerd Font setup for Ghostty + tmux + vim + zsh.

## Conventions — don't drift from these

- **Manual symlinks via `bootstrap.sh`.** Don't introduce `stow`, `chezmoi`, or
  any other dotfiles manager unless asked.
- **Bash scripts target bash 5** (`brew "bash"`). All in-repo bash scripts use
  shebang `#!/opt/homebrew/bin/bash` and may use bash 4+/5 features
  (`mapfile`, `declare -A`, `${var,,}`, `wait -n`, etc.). Mac Apple Silicon
  only. Don't reintroduce `#!/usr/bin/env bash` or bash-3 compatibility
  shims — `brew bundle` runs before `bootstrap.sh` in the README's "Setup
  (new machine)" order, so brew bash is always present before a pinned-
  shebang script runs.
- **`.zprofile` runs `brew shellenv`** to prepend `/opt/homebrew/bin` ahead
  of the system paths that macOS's `/etc/zprofile` (`path_helper`) installs.
  Without it, `bash`, `make`, and other tools resolve to `/usr/bin` versions
  even though brew ships newer ones. Don't move the line into `.zshrc` —
  interactive subshells re-source `.zshrc`, which would re-stack
  `/opt/homebrew/bin` in PATH (the same duplication already visible for
  `~/.cargo/bin` exports there). `.zprofile` runs once per login session
  and child shells inherit cleanly. Machine-specific login-shell init
  (e.g. OrbStack's `source ~/.orbstack/shell/init.zsh`) goes in
  `~/.zprofile.local` (untracked; copy from `.zprofile.local.template`),
  mirroring the `.zshrc.local` pattern. Use `.zprofile.local` rather than
  `.zshrc.local` whenever a tool's init does `fpath+=` or otherwise needs
  to run before `compinit` — `.zshrc.local` is sourced after `compinit`
  (which runs near the top of `.zshrc`), so late `fpath+=` silently
  no-ops there.
- **Zsh module layout.** `.zshrc` is a thin orchestrator (~20 lines: `compinit`,
  one `source` per module, `~/.zshrc.local`, `~/.secrets`). Concerns live in `.config/zsh/<concern>.zsh`:
  `env.zsh` (locale, EDITOR, PATH, MANPAGER, no-bells, emacs keybindings,
  history config, shell options), `colors.zsh`
  (vivid `LS_COLORS`, fzf palette, autosuggest highlight), `mise.zsh`
  (`mise activate zsh` registers a polyglot chpwd hook for `.nvmrc` /
  `.ruby-version` / `.tool-versions`), `tmux-hooks.zsh` (window-label,
  ssh-target, `CLAUDE_CODE_TMUX_TRUECOLOR`), `modern-reminder.zsh`
  (default→modern tool nudge), `prompt.zsh` (Starship init via
  `eval "$(starship init zsh)"`), `aliases.zsh` (color-aware tool aliases +
  bat-backed `less()`), `plugins.zsh` (fzf, zoxide, fzf-tab, wt init,
  autosuggestions, syntax-highlighting — order-critical, header
  comment in the file documents it). Module shape: definitions on
  top, side-effects (hook registration, env exports, alias defs)
  guarded at the bottom by `[[ -n ${ZSH_DOTFILES_TEST:-} ]] && return`.
  Tests source the module with `ZSH_DOTFILES_TEST=1` to get the
  function defs without firing hooks/exports. The three refactored
  test scripts (`test-tmux-window-label.zsh`, `test-modern-reminder.zsh`,
  `test-tmux-ssh-target.zsh`) source the
  real module instead of holding inline duplicates. `~/.zshrc.local`
  sources between `colors.zsh` and `mise.zsh` — after PATH appends but
  before any hook-registering module. Don't add new top-level
  `source` calls to `.zshrc` outside the `.config/zsh/` set; new
  concerns get their own module file.
- **`Brewfile` is report-only.** `bootstrap.sh` runs `brew bundle check` and
  prints what's missing — it does not install. Don't change that.
- **Global gitignore is symlinked from `.gitignore_global`** (repo root,
  sibling of `.zshrc`). `bootstrap.sh` links it to `~/.gitignore_global`,
  the path that `~/.gitconfig`'s `core.excludesfile` already points to —
  so no `git config` change is needed when re-bootstrapping a machine.
  Lists patterns that should never be committed in any repo on this
  machine: Claude Code state (`settings.local.json`, `todos.json`,
  `worktrees/`, `logs/`, `.credentials.json`), and working dirs for
  planning artefacts (`.superpowers/`, `.autonomo/`). Per-repo
  `.gitignore` files still own repo-specific
  patterns; this file is for the cross-repo never-commit set only. Don't
  add app-specific patterns here (e.g. `node_modules/`) — those belong
  in per-language `.gitignore` templates, not the global file.
- **tmux status bar is hand-rolled** in `.config/tmux/tmux.conf` with
  Solarized base16 colors. Don't suggest theme plugins (catppuccin,
  tmux-powerline, etc.) — we deliberately avoid them.
  Each status-bar **pin** uses a unique Solarized accent — never
  duplicated across pins. Currently: blue (session chip, left),
  green (active window pin, center), violet (main-checkout git
  chip, right), yellow (worktree git chip, right), orange (PR pin,
  right — left of git chip). Why: shared color visually merges two
  unrelated signals — the active-pin yellow and worktree-chip
  yellow collision is what drove the active pin off yellow. How
  to apply: when adding a new pin/chip on the status line, pick
  from the currently-unused accents (red, magenta, cyan); if all
  are taken, reconsider whether a new pin is warranted before
  reusing one. Mode-style,
  message-style, pane-borders, and inline text colors (e.g. ins/del
  markers in `tmux-git-status`) are not pins and are exempt from
  this rule.
- **SSH indicator on the session chip** is wired into `status-left` via
  `#(~/.config/tmux/bin/tmux-ssh-indicator)`. The helper walks each
  attached client's parent-process chain on macOS using
  `ps -p <pid> -o ppid=,ucomm=` and emits a Nerd Font globe glyph (``
  `nf-fa-globe`, U+F0AC) plus a single space when any ancestor is `sshd`
  or `sshd-session`. **Use `ucomm`, not `comm`.** macOS `ps -o comm=`
  for sshd's privsep children renders the descriptive argv string
  (e.g. `sshd-session: martinciu@ttys008`, `sshd-session: martinciu [priv]`),
  which never basename-equals `sshd-session` and would silently never
  match. `ucomm` is the kernel-recorded short executable name and is
  always the clean basename. The glyph inherits the chip's `fg=#fdf6e3,bg=#268bd2`
  styling — no color flip, presence/absence is the signal. Detection is
  server-wide (any attached client is SSH → indicator on), not
  per-client: `#(...)` shells run server-global. For a single-user Mac
  with one client at a time this is accurate enough; a per-client design
  would need `client-attached` / `client-detached` hooks and more moving
  parts than the use case warrants. Refresh piggybacks on the existing 5 s
  `status-interval` — don't add a `client-attached` hook for sub-second
  refresh without an explicit ask. Mosh is **not** detected (sessions
  root in `mosh-server`, not `sshd`); add `mosh-server` to the basename
  match set in the script if mosh becomes regular tooling. Env-var
  detection (`$SSH_CONNECTION`) intentionally not used — it's set in
  the SSH-spawned shell's env, not the tmux server's, so `#(...)` calls
  never see it.
- **tmux PR pin** is wired into `status-right` via
  `#(~/.config/tmux/bin/tmux-status-right #{pane_current_path})`. The
  orchestrator calls `tmux-pr-detect` (a stale-while-revalidate file cache
  around `gh pr view --json state,number --jq ...` with TTL 60s, cache at
  `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-pr-pin/<repo-hash>-<branch>`).
  When a PR exists for the current branch (state OPEN or DRAFT — single
  visual, no draft distinction), the orange chip (`#cb4b16`, fg `#fdf6e3`
  bold) rendering ` #<num>` (Nerd Font U+F407 `nf-oct-git_pull_request`)
  is emitted, then `tmux-git-status` is called with `prev_bg=#cb4b16` so
  its existing `tri_l` (U+E0B6) becomes the yellow-on-orange rounded
  separator — falls out of the existing helper for free. Both states
  (with PR / without PR) call `tmux-git-status` with `next_bg=''` so the
  git chip is flush-right (no closing cap), mirroring the session chip's
  flush-left anchor on the opposite side. `<prefix> P` opens the current
  branch's PR in the browser via `gh pr view --web` (silent when no PR
  exists). Cache key uses `git-common-dir` so all worktrees of the same
  upstream repo share entries per-branch. First call after branch switch
  shows nothing; the next 5s status-interval tick (after the background
  refresh completes) renders the pin — acceptable trade-off for never
  blocking the bar on a slow `gh` call. Why orange specifically: it was
  the first unused accent (per the "unique accent per pin" rule); after
  this change red/magenta/cyan remain available.
- **Outbound SSH overlay on the Ghostty tab title.** Distinct from the
  inbound `tmux-ssh-indicator` above: this surfaces *outgoing* `ssh`
  sessions on the local client's Ghostty tab. While an `ssh` command is
  foreground in the active pane, the tab renders ` user@host` (Nerd
  Font globe U+F0AC + canonical destination); otherwise it renders
  `<session>:<window>`. Wired in `tmux.conf` via `set -g set-titles on`
  and a `set-titles-string` that branches on the per-pane
  `@ssh_target` user variable. The pane variable is set/cleared by two
  zsh hooks in `.config/zsh/tmux-hooks.zsh`: `_tmux_record_ssh_target` (preexec) checks
  whether the first whitespace token of the typed command equals `ssh`
  (first-token equality, not prefix — excludes `ssh-add`/`ssh-keygen`),
  resolves the destination via `ssh -G <args>` so `~/.ssh/config` Host
  aliases and default Users canonicalize, and stamps
  `@ssh_target=user@host`. `_tmux_clear_ssh_target` (precmd) unsets it
  on the next prompt. Both hooks call `tmux refresh-client -S` so the
  tab updates instantly rather than waiting for the 5 s
  `status-interval` tick. The precmd hook short-circuits when
  `@ssh_target` is already empty, so non-SSH prompts don't trigger
  spurious refreshes. Per-pane (not server-global) — each Ghostty tab
  shows its own SSH state. The function bodies live in
  `.config/zsh/tmux-hooks.zsh`; `scripts/test-tmux-ssh-target.zsh`
  sources them under `ZSH_DOTFILES_TEST=1` (with mocked `tmux`/`ssh`),
  so there is no duplicate copy to keep in sync. Edge cases: Ctrl-Z'd `ssh`
  is a small known gap (overlay clears on the next prompt even though
  ssh is technically backgrounded — acceptable); nested `ssh` is not
  tracked (only the outer command counts). Don't replace `ssh -G` with
  argv parsing — it would miss `~/.ssh/config` aliases and default
  Users.
- **tmux prefix is `C-a`** (screen-style; `C-Space` conflicts with macOS
  input-source switching). Pane nav: `<prefix> h/j/k/l` (Alt is reserved for
  Polish diacritics — never use `bind -n M-*`). Splits: `|` and `-`.
- **TPM is the tmux plugin manager.** Loaded plugins: `tmux-sensible`,
  `tmux-resurrect`, `tmux-continuum` (`@continuum-restore 'on'` —
  auto-restores the last saved env on tmux start), `tmux-sessionx`. Don't
  remove TPM ("we hand-roll everything") without an explicit ask — the
  status bar is hand-rolled, behavior plugins aren't.
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
  a missing import target. Sesh itself stays installed only as
  `bin/s`'s project registry — it's no longer the picker. The picker
  is `tmux-sessionx` (see next bullet).
- **tmux-sessionx is the session picker** (`<prefix> t`, swapped with
  the default clock-mode binding which moved to `<prefix> T`). Loaded
  via TPM (`omerxx/tmux-sessionx`); the plugin claims the binding via
  `@sessionx-bind 't'` set during TPM `run`, so no manual bind-key
  exists. Geometry is pinned `70% × 70%` (`@sessionx-window-width` /
  `@sessionx-window-height`) — the shared anchor with the URL and
  file pickers. Sources: tmux sessions + tmuxinator
  (`@sessionx-tmuxinator-mode 'on'`); zoxide is intentionally
  **not** a picker source (`@sessionx-zoxide-mode 'off'` set
  explicitly so the house rule is visible in config).
  `@sessionx-filter-current 'true'` hides the current session from
  the list. Preview is sessionx's default — `tmux capture-pane -ep`
  on the highlighted session's active pane (live content). The
  preview script (`preview.sh`) is hardcoded inside the plugin;
  there is no `@sessionx-preview-command` hook, so don't try to
  customize the preview content via tmux options. No custom wrapper
  script; geometry/sources are configured via `@sessionx-*` options
  only. Zoxide is still loaded for `z`-cd, and `_ZO_EXCLUDE_DIRS`
  blocks `~/`, `~/Downloads/*`, `~/.config/*`, `~/Library/*` from
  being indexed — keeps `z lib`/`z config`/etc. from jumping into
  noise dirs.
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
  source); no separate registry. The picker is tmux-sessionx (see
  the sessionx bullet); `s` does not invoke it.
- **`dashboard` is the multi-session live preview command** (`bin/dashboard`,
  symlinked to `~/.local/bin/dashboard` by `bootstrap.sh`). Surface:
  `dashboard <pattern> [--cols N]`, plus internal subcommands
  `--page-down`, `--page-up`, `--rebuild`. Pattern is a session-name
  glob; spawns or rebuilds a `dashboard-<derived>` session with one
  polled `watch + capture-pane` tile per matched session (excluding
  `dashboard-*` themselves so dashboards never tile each other). The
  dashboard prefix uses `-` (not `:`) because tmux silently rewrites
  `:` in session names. `<prefix> J/K` page rows down/up — bindings
  are no-ops outside `dashboard-*` (script bails on `#S`). Bindings
  pass `DASHBOARD_TARGET=#{session_name}` because `display-message
  -p '#S'` inside `run-shell` returns the global most-recent session,
  not the run-shell target. `--cols N` forces an N-column grid via a
  hand-built two-pass split (vertical row seeds, then horizontal
  column splits per row); without it tmux's `tiled` layout is used.
  Don't replace polling with `link-window` (only one window visible
  at a time) or nested `tmux attach` (shows whole client UI). Don't
  auto-install a `--rebuild` keybinding; the user wires `<prefix> R`
  themselves if wanted. The script reads `$TMUX_SOCKET` (test-mode
  socket isolation) and `$DASHBOARD_NO_FINISH` (skip the final
  attach/switch-client — used by the integration tests because
  there's no real client to attach against the test server).
  Production runs leave both unset.
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
- **LSPs are off by default in nvim.** `lua/plugins/lsp-disable-all.lua`
  sets `enabled = false, mason = false` on every LazyVim-core/extra
  server entry (`lua_ls`, `jsonls`, `marksman`, `vtsls`, `ts_ls`,
  `tailwindcss`, `yamlls`, `eslint`, `ruby_lsp`, `rubocop`). Mason
  packages stay installed (so opt-in is instant). Per-session opt-in:
  `:LspOn <name>` (user command in `lua/config/keymaps.lua`, thin
  wrapper over `vim.lsp.enable`). Per-project always-on: drop a
  `.nvim.lua` at the repo root with `vim.lsp.enable({ "vtsls", ... })`
  — requires `vim.o.exrc = true` (not currently set; flip on if you
  start using `.nvim.lua` regularly). Why off by default: first-attach
  blocks the UI 3-6s+ for any LSP (jsonls on `lazy-lock.json`, ruby-lsp
  doing bundle work, marksman scanning a markdown-heavy repo), and
  dotfiles editing rarely needs gd/hover/rename. The
  `VimLeavePre` autocmd in `lua/config/autocmds.lua` force-stops all
  LSP clients on exit so libuv handles drain deterministically —
  without it, opt-in projects leak handles on quit (visible as a
  `uv_print_active_handles` dump in `~/.local/state/nvim/nvim.log`),
  exit non-zero, and leave stale swap files. When LazyVim adds a new
  default server entry, append it to the `servers` list in
  `lsp-disable-all.lua` — one line.
- **`lsp-lua-off.lua` was deleted** when the broader
  `lsp-disable-all.lua` landed. Don't reintroduce per-server opt-out
  files; add to the unified server list instead.
- **No schemastore catalog injection for jsonls/yamlls.**
  `lua/plugins/lsp-no-schema-fetch.lua` overrides LazyVim's
  `before_init` hook (from `lang.json` and `lang.yaml` extras) with
  a no-op so the ~700-entry schemastore.org catalog is never written
  into `settings.{json,yaml}.schemas`. Why: each pattern match
  triggers an HTTP fetch on first validation — fine when online and
  fast, but a freeze risk on flaky networks and unwanted noise on
  every `:LspOn jsonls` for ad-hoc work. Inline `$schema` URLs in
  files still resolve normally. For projects that genuinely want
  the full catalog, drop a `.nvim.lua` at the repo root that
  restores LazyVim's injector — same `vim.o.exrc = true` caveat as
  the per-project always-on path. Don't fold this into
  `lsp-disable-all.lua`; that file's per-server `enabled/mason`
  loop stays pure, and the schema-fetch override is conceptually
  separate (different problem, different remediation).
- **Mason-managed LSPs are pinned** via `mason-lock.json`. The lockfile
  is committed. `:MasonLock` snapshots the current state; `:MasonLockUpdate`
  upgrades to latest then snapshots — use the latter to bump versions.
- **`lazy-lock.json` and `mason-lock.json` are committed** for
  reproducibility across machines.
- **Solarized + JetBrainsMono Nerd Font everywhere — except the starship
  prompt.** Every other tool (tmux, btop, lnav, bat, delta, glow, eza, vivid,
  fzf, procs, tailspin, xh, syntax-highlighting plugins, …) stays Solarized
  Dark. The starship prompt is the documented exception: it uses a single
  pastel rose accent (`#DA627D`) named alongside the Solarized hex codes
  inside `[palettes.solarized_dark]` in `.config/starship.toml`. The chip
  is flush-left (no leading cap) and ends with a U+E0B4 `` rounded right
  cap; the prompt character drops to line 2. Why: a single-chip flush-left
  directory + rounded-right cap reads cleanly without committing to a
  multi-color powerline (which hits a starship parsing limitation where
  `bg:` is silently dropped when both `fg:` and `bg:` reference custom
  palette names in the top-level format string). How to apply: don't
  extend the pastel palette to other tools without an explicit ask, and
  don't add chips with `(fg:custom_a bg:custom_b)` styles in the format
  string — they will render with `bg` missing.
- **wt user config is symlinked from `.config/worktrunk/config.toml`.**
  Per-project hook approvals (`approvals.toml`) are machine-local and
  gitignored.
- **Gitignored content flows between primary and worktrees in two
  stages, both using `wt step copy-ignored`.** `[post-start] copy = "wt step copy-ignored"`
  reflinks primary's gitignored content into a new worktree at
  creation. `[pre-remove] save-shared = "wt -C {{ primary_worktree_path }} step copy-ignored --from {{ branch }}"`
  reflinks the worktree's gitignored content back to primary just
  before `wt remove`. Default no-`--force` semantics on both: files
  that already exist in the destination are never overwritten —
  primary's specs/plans/logs are safe from a worktree's diverged
  copies, and the worktree starts cold-free with primary's exact
  state. Auto-discovers any new gitignored top-level dir (e.g.
  `autonomo-workspace/`) — no per-path hook edits needed when a new
  tool drops state. Caveat: `step.copy-ignored.exclude` is shared
  across both directions, so derived-state dirs (`node_modules/`,
  `target/`, `.next/`, `dist/`) carried in on post-start will also
  flow back on pre-remove if a worktree mutated them via
  `npm install` / `cargo build` / etc. Accepted trade-off — see
  the design doc referenced from `config.toml`. Don't reintroduce
  per-path symlink hooks (the previous `share-tmp` design) without
  explicit ask — keep this simple.
- **Worktree status segment** uses `git rev-parse --git-dir` vs
  `--git-common-dir` for detection (works for `.claude/worktrees/*`,
  worktrunk paths, sibling worktrees alike). Don't replace with
  `git worktree list` parsing.
- **tmux window name follows the active pane's last typed command.**
  zsh `preexec` hook `_tmux_record_last_cmd` (in `.config/zsh/tmux-hooks.zsh`)
  sets a per-pane `@last_cmd` user variable; `tmux.conf` enables
  `automatic-rename` with a format that reads it. Env-var assignments are
  stripped, then the first two whitespace-separated tokens are used.
  `allow-rename off` stays so OSC titles from apps (e.g. Claude Code) cannot
  override. Don't replace with `automatic-rename off` or wire app-specific
  renames without an explicit ask. `scripts/test-tmux-window-label.zsh`
  sources the same module under `ZSH_DOTFILES_TEST=1`, so the label
  function `_tmux_window_label` has no duplicate copy.
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
- **Terminal tools are Solarized Dark, end-to-end.** Tools: `eza` (ls),
  `bat` (cat + `MANPAGER`), `git-delta` (git pager), `glow` (`md` markdown
  renderer), `vivid` (`LS_COLORS`), `procs` (`ps` replacement),
  `tailspin` (`tspin`, live-log highlighter),
  `xh` (modern HTTP client; HTTPie-compatible CLI),
  `zsh-syntax-highlighting`, `zsh-autosuggestions`, `fzf-tab` (Tab completion
  picker). Palette pins:
  `vivid generate solarized-dark`, `bat --theme="Solarized (dark)"`,
  `delta.syntax-theme = "Solarized (dark)"`, `procs` reads
  `.config/procs/procs.toml` (Pid=violet, User=blue, percentage gradient
  blue→green→yellow→red),
  `md` alias passes `--style .config/glow/glamour.json` (chroma
  `solarized-dark` for fenced code blocks),
  `tspin` reads `.config/tailspin/theme.toml` — minimal pin via ANSI
  color names (Ghostty's Solarized palette resolves them to hex; e.g.
  `bright_red` → orange `#cb4b16`, `bright_magenta` → violet `#6c71c4`,
  `bright_green` → base01). Severity keywords
  (`error`/`warn`/`info`/`debug`) are shipped as `[[keywords]]` blocks
  since tspin has no built-in groups for them. Invocation stays explicit
  — `tspin file.log` / `tspin -f file.log` / `cmd | tspin -p`. No `tail`
  alias, no `t` shortcut (keeps `tail` vanilla, limits surface area, and
  avoids breaking `tail -n` since tspin's CLI isn't a `tail` superset).
  Don't swap themes or introduce alternatives
  (`exa`, `lsd`, `diff-so-fancy`, `mdcat`, `lnav`, etc.) without asking.
  Plugin source order in `.config/zsh/plugins.zsh` is fixed: fzf →
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
- **Interactive `less` is a `bat` wrapper** (defined in `.config/zsh/aliases.zsh` next to the
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
- **`top` is a zsh alias to `btop`** (defined in `.config/zsh/aliases.zsh`, guarded on
  `command -v btop`). Theme is pinned `solarized_dark` via
  `.config/btop/btop.conf` (only `color_theme`,
  `theme_background = False`, and `vim_keys = True` are pinned —
  everything else rides btop defaults). macOS `top` is reachable via
  `command top` or `\top`. Don't replace btop with htop or vendor a
  custom Solarized theme file — `solarized_dark` is built-in. Don't
  pin more keys without a clear reason — small diff = easy upstream
  bumps.
- **`lnav` is the TUI log navigator** (homebrew `lnav`; raw command, no
  alias). Only the two `installed/` subdirs are symlinked from the
  repo: `bootstrap.sh` creates `~/.config/lnav/` as a real dir, then
  links `~/.config/lnav/configs/installed` and
  `~/.config/lnav/formats/installed` (dir-level) into the repo. lnav
  owns the rest of the tree — built-in samples (`configs/default`,
  `formats/default`), `crash/`, `staging/`, `log_metadata.db`,
  per-PID `view-info-*.json`, and `:config`-written `config.json`
  all live in the real `~/.config/lnav/` outside the repo. Don't
  re-introduce the whole-dir symlink — the runtime artifacts polluted
  `git status` (issue #64). Theme is lnav's **built-in**
  `solarized-dark`, activated by
  `.config/lnav/configs/installed/solarized-dark.json` — one tiny
  file that only sets `ui.theme`; no slot-mapping JSON because
  upstream's built-in already uses the canonical Solarized palette
  (verified). Don't redefine the theme; if you need a tweak, prefer a
  separate config file that overrides specific slots rather than
  forking the whole theme. Custom log-format files live at
  `.config/lnav/formats/installed/<name>.json`. One tracked format
  today: `inngest.json` for `inngest-cli dev` stdout — uses lnav's
  `"json": true` mode (Inngest CLI v1.x emits JSON-per-line) and maps
  `time`/`level`/`msg` to lnav's `__timestamp__`/`__level__`/body
  slots. Add new formats by dropping a JSON file in `installed/` — no
  `bootstrap.sh` re-run needed because `installed/` itself is the
  (dir-level) symlink. `lnav -i <path>` also writes into `installed/`
  and therefore into the repo — that's intended (installed configs
  become tracked dotfiles), but worth knowing. Don't replace lnav
  with another log TUI without an ask; don't add a shell alias or
  wrapper.
- **`diff` is a zsh alias to `difft`** (defined in `.config/zsh/aliases.zsh`, guarded on
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
- **`xh` is the interactive HTTP client** (Rust, HTTPie-compatible CLI).
  Ships as `xh` (HTTP-default) and `xhs` (HTTPS-default) — used under
  their own names. Theme pinned via `.config/xh/config.json`:
  `{"default_options": ["--style=solarized"]}`; xh's `--style` accepts
  `auto`/`solarized`/`monokai`/`fruity` and is rendered through `syntect`
  (same library family as `bat`). Per-invocation overrides
  (`xh --style=monokai …`) still work. **Don't alias `curl` to `xh`** —
  `curl` stays available verbatim for scripts and CI. **Don't add an
  `http`/`https` alias** either; the rule is "no synonyms, just the
  binary's name". No `.zshrc` change for this tool.
- **`hyperfine` is the benchmark tool, additive to `time`** (homebrew
  `hyperfine`; raw command, no alias, no wrapper, no shell-config). `time`
  (zsh builtin / `/usr/bin/time`) stays the default for one-shot wall-clock
  measurements; reach for `hyperfine` when you need warmups, multiple runs,
  or A/B comparisons (`hyperfine 'cmd-a' 'cmd-b'` produces a relative
  summary). Output is ANSI-colored and inherits Ghostty's Solarized
  palette — there is no static config file format (CLI flags only), so no
  theme pin is needed. **Deliberately NOT in the modern-reminder catalog.**
  The catalog's inclusion criterion is "modern alternative for the same
  use case" (`tail`/`tspin`, `grep`/`rg`, `curl`/`xh` are 1:1 same-use
  swaps); `time foo` runs once, `hyperfine 'foo'` benchmarks N times with
  warmups — different use cases, not the same use case. A reminder firing
  after every `time` invocation would mis-fire on most of them. This is
  the explicit-rejection record so the next "modern alternative" candidate
  can re-use the same evaluation. Don't alias `time` to `hyperfine`, don't
  ship a wrapper that pins `--warmup` defaults (warmup count is workload-
  specific — wrong as often as right). No `.zshrc` change for this tool.
- **`modern-reminder` is a zsh-level discoverability nudge** for default→modern
  tool pairs that this setup intentionally leaves *unaliased* (the "no synonyms,
  just the binary's name" pattern shared by `tail`/`tspin`, `grep`/`rg`, and
  `curl`/`xh`). Defined in `.config/zsh/modern-reminder.zsh` as two associative arrays
  (`_modern_reminder_pairs`, `_modern_reminder_hints`), plus
  `_modern_reminder_preexec` (scan-all-tokens via `${(z)…}`, strips leading
  `\` and dirname) and `_modern_reminder_precmd` (env-var guard, once-per-shell
  seen set, `command -v` check, `print -P "${_modern_reminder_hints[$cmd]}"`).
  Each hint embeds its own Nerd Font glyph as a `\u…` escape and Solarized
  yellow via `%F{yellow}%f` so `print -P` decodes both at runtime — keeps
  source 7-bit ASCII and avoids editor/clipboard mangling of private-use
  codepoints. Don't put backticks or `$(…)` inside hint text: under
  `PROMPT_SUBST` (set by starship init), `print -P` performs command substitution on
  the prompt string. Use single quotes for sample-syntax emphasis. Toggled
  by `export MODERN_REMINDER=1`; comment that line to disable. State is
  per-zsh-process — a fresh tmux pane resets the seen set. Tests:
  `scripts/test-modern-reminder.zsh` sources the module under
  `ZSH_DOTFILES_TEST=1`, so there is no duplicate copy of the function
  bodies. **When introducing a new modern terminal
  tool under the "no synonyms" pattern, evaluate it against the inclusion
  criteria (default in common interactive use; modern alternative installed and
  Solarized-themed; default deliberately unaliased) and add it to
  `_modern_reminder_pairs` and `_modern_reminder_hints` in the same change.
  Symmetrically, if a default tool gains an alias to its modern alternative
  later, drop it from the catalog** — no point reminding when the alias already
  redirects.

## Where things live

- Sources: `$PROJECTS_HOME/dotfiles/{.config,.vimrc,.vim/colors,.zshrc,.zprofile,.gitignore_global,.claude/CLAUDE.md}` (`.config/` includes `nvim/`, `worktrunk/`, `glow/`, `zsh/`, `starship.toml`)
- Targets: `~/.config/{ghostty,tmux,ccstatusline,nvim,worktrunk,glow,zsh}`, `~/.config/sesh/sesh.toml`, `~/.config/starship.toml`, `~/.local/bin/<command>`, `~/.vimrc`, `~/.vim/colors`, `~/.zshrc`, `~/.zprofile`, `~/.gitignore_global`, `~/.claude/CLAUDE.md`
- The repo's `.claude/CLAUDE.md` IS the user-global Claude config (symlinked to `~/.claude/CLAUDE.md`). Edits there apply to every project on this machine, not just dotfiles.
- Machine-specific overrides: `~/.zshrc.local` (untracked; copy from `.zshrc.local.template`)
- Helpers: `.config/tmux/bin/{tmux-git-status,claude-tmux-window-name,tmux-ssh-indicator}`
- Smoke tests for helpers: `scripts/test-helpers.sh`

## Cheatsheets (`docs/`)

Three standalone HTML reference pages live in `docs/` — Solarized-styled, print-friendly,
generated by hand from the live config and pinned to today's setup:

- `docs/nvim-cheatsheet.html` — LazyVim leader map, picker, LSP, neotest, Mason/Lazy
- `docs/terminal-cheatsheet.html` — eza, bat, less wrapper, git-delta, glow/`md`,
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

Each cheatsheet, the landing page, and the README also embed example
screenshots. Sources live at `docs/images/example_<tool>.png` (3176×1920
PNG, retina-captured by hand). Two derivative sizes — `-hero.png`
(1600px longest side, used at the top of each cheatsheet) and
`-thumb.png` (800px longest side, used on the landing-page cards and
in the README grid) — are produced by `scripts/build-screenshots.sh`
(macOS `sips`). All three sizes are committed; re-run the script after
swapping a source PNG, and never hand-edit a `-hero` / `-thumb` file.
The shared `.shot` / `.shot.hero` rules in `docs/style.css` style every
embedded image; `@media print { .shot { display: none } }` keeps
cheatsheet print output text-only. `<tool>` is one of
`tmux | vim | terminal` — note the source filename is `example_vim.png`
even though the cheatsheet is `nvim-cheatsheet.html` (the user's
filename is the source of truth).

## Verify changes

- Helper smoke tests: `scripts/test-helpers.sh`
- Regenerate screenshot thumbnails: `scripts/build-screenshots.sh`
- Tmux window-label tests: `scripts/test-tmux-window-label.zsh`
- Modern-reminder tests: `scripts/test-modern-reminder.zsh`
- Pre-remove save-shared tests: `scripts/test-wt-pre-remove-save.sh`
- Claude tmux window-name tests: `scripts/test-claude-tmux-window-name.zsh`
- tmux SSH-indicator tests: `scripts/test-tmux-ssh-indicator.sh`
- tmux SSH-target (outbound overlay) tests: `scripts/test-tmux-ssh-target.zsh`
- Session-root binding tests: `scripts/test-s-session-root.sh`
- Dashboard smoke + integration tests: `scripts/test-dashboard.sh`
- Reapply symlinks (idempotent): `$PROJECTS_HOME/dotfiles/bootstrap.sh`
- Check brew deps without installing: `brew bundle check --file=$PROJECTS_HOME/dotfiles/Brewfile --verbose`
- nvim plugin smoke test: `scripts/test-nvim.sh`

## First-time setup on a new machine

See [`README.md`](README.md) → "Setup (new machine)".
