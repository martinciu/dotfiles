# dotfiles — Claude Code instructions

Personal multi-theme, multi-font setup for Ghostty + tmux + vim + fish.
`theme-set` swaps 10 themes (Solarized Dark / Catppuccin Mocha·Frappé·Latte /
Dracula / Gruvbox / Tokyo Night Storm / Nord / Rose Pine·Moon); `font-set`
swaps 17 Nerd Fonts. Both switch live. Solarized Dark + JetBrains Mono are the
bootstrap defaults. See "Switchable themes" / "Switchable Ghostty fonts" below.

## Conventions — don't drift from these

- **Manual symlinks via `bootstrap.sh`.** No `stow`/`chezmoi`. Tools whose
  `~/.config/<tool>/` holds only tracked content get whole-dir symlinks
  (`link`); tools mixing tracked + machine-local/runtime state (fish, nvim,
  worktrunk, lnav, sesh) use the **mixed-dir pattern**: real dir, per-file
  symlinks for tracked entries, real files for the rest. Helpers:
  `prepare_real_dir` + `rescue_in_repo` + `link_tracked_entries`
  (iterates `git ls-files` — untracked/gitignored never link; skips
  `*.template`) + `seed_local`. Legacy whole-dir symlinks migrate
  automatically on next run; `rescue_in_repo` heals symlinks-into-repo
  and warns when repo-side + `$HOME` copies both exist (#370). Smoke:
  `scripts/test-bootstrap-linking.sh`.
- **Bash scripts target bash 5.** Shebang `#!/opt/homebrew/bin/bash`; Apple
  Silicon only (`brew bundle` runs first). `mapfile`/`declare -A`/`wait -n`
  OK. No bash-3 shims.
- **Fish is the primary shell**, config in `.config/fish/` (mixed-dir):
  `config.fish` + `functions/` symlinked, `conf.d/` and `completions/` are
  real dirs with per-file symlinks. `config.fish` is empty; concerns split
  into ordered `conf.d/<NN>-<concern>.fish`: `00-env`, `10-colors`, `15-local`
  (untracked), `20-mise`, `25-prompt` (starship), `30-aliases`,
  `35-abbreviations` (git-flow abbrs), `40-plugins` (fzf/zoxide/wt),
  `45-atuin`, `50-moshi-tmux` (phone → bar-less tmux twin), `99-secrets`
  (untracked). `15-local`/`99-secrets` are real files
  seeded from `.template` companions. `completions/`: `s.fish`/`wt.fish`
  tracked, machine completions real. Smoke: `scripts/test-fish-loads.sh`.
- **`atuin` owns Ctrl-R only** (`45-atuin.fish`, loaded after fzf so its
  rebind wins). `--disable-up-arrow` keeps Up on fish's native history. Sqlite
  at `~/.local/share/atuin/history.db` (machine-global). Picker:
  `filter_mode=global`, `enter_accept=false` (Enter pastes, Tab runs), ANSI-
  palette theme (auto-adapts, no `theme-set` coupling). Failed commands shown,
  not hidden. Revert: delete the file. First run: `atuin import fish`.
- **`Brewfile` installed by bootstrap** unconditionally before symlinks;
  aborts on failure. **`Brewfile.local`** (gitignored, optional) is a
  machine-local overlay bundled right after, for packages wanted on one
  machine only; absent ⇒ skipped (no-op).
- **Global gitignore symlinked from `.gitignore_global`** → `~/.gitignore_global`.
  Cross-repo never-commit set (Claude state, `.superpowers/`, `.autonomo/`).
  Don't add language patterns — those belong in per-language `.gitignore`.
- **tmux status bar hand-rolled** (`.config/tmux/tmux.conf`, Solarized base16,
  no theme plugins). Each **pin** uses a unique Solarized accent (session=blue,
  active window=green, git chips=violet/yellow, PR=orange, usage-cost=red);
  new pins pick an unused accent (magenta/cyan). Palette reuse across left (usage cluster)
  and right (git chips) clusters is by design — positional, not paired.
  Mode/message/border/inline colors aren't pins.
- **SSH indicator on the session chip** (`tmux-ssh-indicator`). Walks each
  client's parent chain via `ps -o ppid=,ucomm=`, shows a globe glyph when an
  ancestor is `sshd` or `mosh-server` (same glyph — the pin means "remote
  client attached"). Clients in `@phone_twin` sessions are skipped (#366) —
  the globe means "a remote client *other than the phone* is attached".
  **Use `ucomm`, not `comm`** (comm renders sshd's argv and
  never basename-matches).
- **Moshi/mobile clients land in a bar-less tmux twin — tmux-side** (#366, #372):
  a `client-attached` hook (`tmux-phone-attach`) classifies every attaching
  client (remote ancestry via shared `_remote-ancestry` + `client_termname
  != xterm-ghostty`); phone clients are switched into `<target>-phone`, a
  grouped twin built by `tmux-phone-twin` (`status off`, `@phone_twin`
  marker, stale-resurrect kill, twin-of-twin guard; `destroy-unattached on`
  set only after entry), then the conf is re-sourced to repair Moshi's
  `set -g status-right ''` clobber (PR pin + continuum hook). Both hooks —
  `client-attached` and `client-session-changed` — fire the same idempotent
  handler: Moshi ≥0.2.51 drives tmux out-of-band via `switch-client` (fires
  session-changed, never attached), so the switch path needed its own wiring
  (#372); the handler's re-source is gated on a shared `_statusbar-clobbered`
  predicate so the switch's self-fire does no redundant work. `tmux-statusbar-guard`
  (an invisible `#()` in status-left) re-sources the conf whenever it sees
  global `status-right` empty — the belt-and-braces catch-all for any future
  clobber path (#372). Covers the session-picker path that never spawns fish;
  `50-moshi-tmux.fish` keeps only login auto-attach (`MOSHI_CLIENT=1` → ensure
  `notes` → attach `notes-phone`). `window-size latest` (pinned in tmux.conf)
  keeps Mac windows full-size. ccstatusline guarded machine-locally in
  `~/.claude/settings.json` (`[ "$MOSHI_CLIENT" = 1 ] ||`). Smoke:
  `scripts/test-moshi-tmux.sh`, `test-phone-twin.sh`, `test-phone-attach.sh`,
  `test-statusbar-guard.sh`.
- **`moshi-theme` exports the active theme to the Moshi iPhone terminal**
  (fish fn; `moshi-theme [<name>] [--qr]`). Payloads come from committed
  `.config/themes/moshi-<slug>.json` (Moshi v1), generated by
  `scripts/build-moshi-themes.py` from Ghostty.app's **bundled** palettes
  (repo `theme-*.ghostty` files only hold `theme = <Name>` pointers +
  overrides, which win — e.g. solarized selection). Prints a tappable
  `moshi://theme?d=<b64>` deep link (works from Moshi over mosh), pbcopy's
  the `moshi-theme:<b64>` string; `--qr` renders via `qrencode` (Brewfile).
  Import is manual on the phone (no push API). Generator needs Ghostty.app;
  the committed JSONs keep the fn working everywhere else. **Out of sandbox
  scope** (phone pairs with the Mac). Smoke: `scripts/test-moshi-theme.sh`.
- **tmux PR pin** in `status-right` (`tmux-status-right` → `tmux-pr-detect`,
  stale-while-revalidate cache around `gh pr view`, TTL 60s). Orange chip
  ` #<num>` when a PR exists (OPEN or DRAFT); `<prefix> P` opens it on web.
  Cache key uses `git-common-dir` so worktrees share entries. First call after
  a branch switch shows nothing; next 5s tick renders (never blocks on `gh`).
- **tmux Claude usage cluster** in `status-left` (`tmux-claude-usage`, parses
  `ccpulse status --json --index` each 5s tick; `--index` tails new JSONL so
  throughput is live). Two always-on chips: violet 7d weekly + yellow
  5h block, each showing `<pct>%` + reset, plus a red cost chip rendered
  **after** the 5h block when ccpulse reports throughput. Overreach decoration
  (fire + projected %) when `projection.<window>.will_overreach` **and**
  `projection.<window>.confidence != "low"` — a low-confidence projection
  (noisy early-window extrapolation) neither decorates nor auto-expands;
  default-to-ok when the field is absent (older ccpulse). 7d chip auto-expands
  at pct≥80 or on a trusted overreach. The red cost chip shows `$xx/h` (plain
  text, no glyph) from `throughput.cost_per_hour_usd` (`LC_ALL=C printf
  '$%.0f/h'`, rounded, `$0/h` when idle); the 5h chip's right cap fuses into
  it. Graceful degradation: missing `projection` keeps the cluster (drops the
  decoration); missing `throughput` drops the red cost chip (5h closes straight
  into the bar); missing any of the 3 core fields hides it atomically (an idle 5h — `minutes_to_reset: null` — drops just the 5h reset suffix, not the whole cluster, #339).
- **tmux prefix `C-a`** (`C-Space` clashes with macOS input-source switch).
  Pane nav `<prefix> h/j/k/l`; splits `|` `-`. **Cycling pairs are
  single-canonical** (one combo per motion): windows `,`/`.`, sessions
  `Tab`/`S-Tab`/`Space`, reorder `<`/`>` (`swap-window -d`). Defaults
  `n`/`p`/`(`/`)`/`L` unbound; the `C-p`/`C-n` unbinds must run *after* tpm
  (the plugin re-applies them). All `-r` for repeat.
- **tmux-fingers** (`Morantron/tmux-fingers`, TPM): `<prefix> F` copy-mode,
  `<prefix> J` jump-mode. Hint mode: `Ctrl+letter`=open, `Shift+letter`=paste,
  `Tab`=multi-select. Hint colors use ANSI palette refs (auto-adapt). Custom
  patterns: `worktree-…` branches, `#\d+` refs. Fresh machine: after
  `prefix+I` pick "Build from source" (`crystal` is in Brewfile).
- **TPM is the tmux plugin manager.** Loaded: `tmux-sensible`,
  `tmux-resurrect`, `tmux-continuum` (restore on, auto-save 15 min),
  `tmux-sessionx`, `tmux-fingers`. Status bar is hand-rolled; don't remove
  TPM. Theme + status block sits **above** the TPM `run` — continuum
  prepends its auto-save hook to `status-right` at load; re-setting status
  options after TPM kills periodic auto-save (#357). Smoke:
  `scripts/test-tmux-conf-shape.sh`.
- **OSC 8 hyperlinks pass through tmux** via two `terminal-features`
  `:hyperlinks` entries — without them Claude Code's file-ref links don't
  render. `file://` routing uses macOS defaults (no `duti`).
- **Option key split: left = Alt, right = Polish.** `macos-option-as-alt = left`
  routes left-Option to ESC-prefixed "Alt+key" sequences (atuin / readline /
  nvim / tmux read these); right-Option still types Polish diacritics. Not
  `right_cmd` (Ghostty rejects sided modifiers; `key-remap` drops the byte).
  Companions: `set -g extended-keys on` (tmux, so modifier+arrow CSI reaches
  inner apps) and `keybind = alt+arrow_left/right=unbind` (Ghostty, so its
  word-jump doesn't shadow tmux pane-resize). Trade-off: no Polish in Ghostty
  via left-Option; use Alt+b / Alt+f for word-jump. Smoke:
  `scripts/test-ghostty-config.sh`.
- **Sesh config split: shared + machine-local.** Repo tracks
  `.config/sesh/sesh.toml` (`Home` session + `import` of `sesh.local.toml`).
  Machine sessions go in the untracked local file (seeded from template). Don't
  drop the `import` line (sesh hard-errors on missing imports). Sesh isn't the
  picker — `tmux-sessionx` is.
- **tmux-sessionx is the session picker** (`<prefix> t`; clock-mode →
  `<prefix> T`; TPM `omerxx/tmux-sessionx`). 70%×70%, sources tmux +
  tmuxinator, zoxide off, filter-current on. Zoxide still loaded for `z`-cd
  (`_ZO_EXCLUDE_DIRS` blocks `~`, Downloads, .config, Library).
- **`s` is the worktree+session command** (`bin/s` → `~/.local/bin/s`).
  `s [<project>] [<name>]`: inside tmux single arg = worktree name (project
  from cwd); outside = project name; two args = `<project> <name>`. Session
  names use `/`. Branch name verbatim — `s` does **not** apply `worktree-`
  (reserved for `EnterWorktree`). Completions in `completions/s.fish`
  (non-exclusive — fresh names still create).
- **`vim`/`vimdiff` alias to nvim; `vi` is `command vim`** (legacy minimal vim,
  `.vimrc` + `solarized8`). All guarded on `command -v nvim`. Don't add
  vim-plug / LSP to minimal vim.
- **nvim is LazyVim**, Solarized, at `.config/nvim/` (mixed-dir: `init.lua`,
  `mason-lock.json`, `lua/` tracked; `lazy/`/`mason/`/`site/`/lockfiles real).
  Don't replace LazyVim.
- **LazyVim Alt-keymaps kept** (`<A-j>`/`<A-k>` move-line) — safe because the
  Option split makes left-Option emit `<A-x>`. Don't reinstate the
  `pcall(del, …, "<A-j>")` block in `lua/config/keymaps.lua` (pre-split
  workaround).
- **LSPs off by default in nvim** (`lua/plugins/lsp-disable-all.lua`:
  `enabled=false, mason=false` on every LazyVim server; Mason packages stay for
  instant opt-in). Enable per-session `:LspOn <name>` or per-project `.nvim.lua`
  + `vim.lsp.enable`. The `VimLeavePre` autocmd force-stops LSP clients on exit
  (else handle leaks + stale swaps). New servers: append to the list.
- **No schemastore catalog injection** (`lua/plugins/lsp-no-schema-fetch.lua`
  no-ops LazyVim's `before_init`) — the ~700-entry catalog would each trigger
  an HTTP fetch (freeze risk). Inline `$schema` URLs still resolve.
- **Mason LSPs pinned** via `mason-lock.json` (tracked; `:MasonLock` /
  `:MasonLockUpdate`). `lazy-lock.json` is gitignored (churn noise; use
  `:Lazy restore` for single-machine reproducibility).
- **Switchable themes (10).** `theme-set <name>` (fish function) flips
  machine-local active-theme symlinks across hot-path + file-viewer tools.
  Palette files in `.config/themes/` (mixed-dir: tracked `*.tmux` +
  `delta-*.gitconfig`; machine-local `current.tmux` / `delta-current.gitconfig`
  symlinks). Per-tool variants follow `*-<theme>.<ext>` next to each tool's
  config (ghostty/glow/gh-dash/lnav/eza + `starship-<theme>.toml`); active picked
  via a machine-local symlink. tmux reads `@color_*` user options from the
  sourced palette; bat (`$BAT_THEME`) and vivid (`$VIVID_THEME`) are fish
  universal vars set by `theme-set`; fzf/atuin/fx auto-adapt via ANSI palette refs
  (no per-theme files). **gh-dash is the exception** — its `config.yml` is
  generated (`cat config-base.yml theme-colors-<name>.yml`) since it has no YAML
  includes (see the gh-dash bullet). **Adding a theme:** drop the variant files
  in (existence-guarded `test -f` in `theme-set.fish` auto-engages — partial
  coverage is fine; Latte is the only light theme and ships ghostty/tmux/
  starship/eza/btop/tealdeer only, #215) **and** add the `starship-<theme>.toml` `link` line in
  `bootstrap.sh` (the one tool not covered by `link_tracked_entries`) **and**
  add a `case` in `theme-set.fish`'s `switch $name` block setting `btop_theme`
  (btop names differ: e.g. `tokyo-night`→`tokyo-storm`, `gruvbox`→`gruvbox_dark`;
  brew-bundled themes also need a loop entry in `bootstrap.sh`, vendored ones
  auto-link via `link_tracked_entries`) **and** register it in
  `scripts/build-theme-colors.py` (`THEMES` + `BG` maps; `BG` = terminal bg/fg
  read from Ghostty's bundled theme), then re-run it to refresh
  `docs/theme-colors.html` (the per-theme color reference page) **and** re-run
  `scripts/build-jnv-configs.py` (reads the new theme's tmux `@color_*` palette →
  emits `config-<slug>.toml`; no list edit needed — it iterates the canonical slugs)
  **and** re-run `scripts/build-moshi-themes.py` (reads the new theme's
  Ghostty bundled palette → commits `moshi-<slug>.json`; needs Ghostty.app).
  Fallbacks: bat lacks Tokyo Night + Rose Pine → both fall back to Catppuccin
  Mocha; lnav themes for gruvbox/tokyo-night/nord/rose-pine are vendored in
  `configs/installed/` (lnav 0.14 doesn't ship them). nvim picks its colorscheme
  at startup from `readlink` of `current.tmux` (`lua/config/theme.lua`).
  Bootstrap "don't clobber" guards preserve a prior pick. Out of v1:
  procs/tailspin/xh/ccstatusline retheme, cheatsheet/screenshot toggle, live
  nvim retheme. Smoke: `scripts/test-theme-switch.sh`.
- **Switchable Ghostty fonts (17 Nerd Fonts).** `font-set <name> [<weight>]
  [<size>]` (fish function) flips a machine-local symlink
  `~/.config/ghostty/font.ghostty` → a per-font one-liner include; weight
  rewrites `font-weight.ghostty`, size rewrites `font-size.ghostty`. Omit either
  to keep current. `config.ghostty` pulls family+size+weight via three
  `config-file` directives; `ghostty +reload` is live. Per-font advertised
  weights live in `__font_set_weights_for.fish` (validation + completion source
  of truth). **Add a font:** drop `font-<short>.ghostty`, append the cask to
  `Brewfile`, extend the `switch` in `font-set.fish` + 1st-arg completion +
  `__font_set_weights_for`. No nvim/tmux/bat coupling.
- **Starship pastel accent — per theme** (`pastel_rose` in each config's
  `[palettes]`). Single flush-left chip ending in a powerline cap; prompt char
  on line 2. Single chip because starship drops `bg:` when both fg+bg are custom
  palette names. Don't extend pastel to other tools. Fish opts into transient
  prompt (`enable_transience` in `25-prompt.fish`) — after Enter the chip
  becomes a bold `❯`. Starship 1.25.x has no `[transient_prompt]` section; don't
  add one.
- **wt config symlinked** from `.config/worktrunk/config.toml` (mixed-dir;
  per-project `approvals.toml` is real, outside the repo).
- **Gitignored content flows between primary and worktrees** in two stages,
  both `wt step copy-ignored`: `[post-start] copy` in at creation,
  `[pre-remove] save-shared` back before removal. No `--force` (never
  overwrites). Auto-discovers new gitignored top-level dirs; `exclude` is shared
  across directions. Don't reintroduce per-path symlink hooks.
- **Worktree status segment** detects via `git rev-parse --git-dir` vs
  `--git-common-dir`. Don't replace with `git worktree list` parsing.
- **Bells silenced at every layer** (Ghostty `bell-features=`, vim `belloff=all`,
  tmux bell/visual/monitor off). Don't re-enable.
- **Terminal tools default Solarized Dark; some follow `theme-set`.** Follow:
  `bat`, `git-delta`, `glow`/`md`, `vivid`/`LS_COLORS`, `eza` (`ll`/`ls` —
  per-theme `~/.config/eza/theme.yml` themes git/perms/icons/headers beyond
  `LS_COLORS`; 10/10, nord hand-mapped; re-read per invocation so the next
  `ll` is themed; needs `EZA_CONFIG_DIR=~/.config/eza` exported in
  `00-env.fish` — eza 0.23 ignores the documented `~/.config/eza` default and
  only reads `theme.yml` from `$EZA_CONFIG_DIR`; sandbox themes it at creation
  via `stage_theme`), fzf, atuin, `btop`, `lazygit`, `tealdeer` (`tldr`; live
  tier — re-reads config each invocation; `TEALDEER_CONFIG_DIR` redirect mirrors
  eza's `EZA_CONFIG_DIR`), `jnv` (live tier; per-theme config-<name>.toml). Stay
  Solarized-only: `procs`, `tailspin` (`tspin`), `xh`. `bat --theme="Solarized
  (dark)"` is the unset fallback. No `tail` alias. Don't introduce alternatives
  (`exa`/`lsd`/`diff-so-fancy`/`mdcat`). Delta git config: README → Setup. `fzf`/`atuin`/`fx` auto-adapt via ANSI palette refs (no per-theme files).
- **`ps` → `procs`** (`.config/procs/procs.toml`; `psh` loads
  `procs-heavy.toml` via `--load-config`, which replaces the whole config so
  style blocks duplicate). Escape: `command ps`/`\ps`. macOS shows only the
  current user; `\ps -ax` for all.
- **Interactive `less` is a `bat` wrapper** (`functions/less.fish`); piped input
  uses `--plain`. `command less` for `+F`/`-R`. Don't `alias less=bat` or set
  `$PAGER=bat`.
- **`md` renders markdown via `glow`** (fish function `functions/md.fish`, not
  an alias; `--style .config/glow/glamour.json`, because glow reads from
  `~/Library/Preferences/glow/` on macOS). **Wraps to the current terminal/pane
  width** — passes `--width $COLUMNS` when stdout is a tty (glow reads width
  once at launch; resize + re-run to re-flow — one-shot/pager modes don't
  re-render), and drops `--width` for piped output so redirected renders stay
  deterministic (glow.yml's width). A later user `-w`/`--width` overrides
  (cobra takes the last flag), so `md -w 100 file` still works. **`mdp` =
  `md -p`** through `$PAGER` (inherits the width). Don't swap to
  `mdcat`/`frogmouth`.
- **`nvimpager` is the global `$PAGER`** (`00-env.fish`, guarded). Loads its own
  `~/.config/nvimpager/init.lua` (not the nvim config), reusing nvim's lazy
  `snacks.nvim` for scroll (existence-guarded — fresh machine works without
  animation). `man` (`MANPAGER=bat`) and `git` (delta) unaffected. Smoke:
  `scripts/test-nvimpager.sh`.
- **`top` → `btop`** (`vim_keys`; follows `theme-set` across all 10 themes).
  `command top` for macOS. `btop.conf` sets `color_theme = "current"` (existing
  machines converged by a guarded `bootstrap.sh` migration that rewrites that
  line); `~/.config/btop/themes/current.theme` is a machine-local symlink
  flipped by `theme-set` (restart tier — btop has no live reload). Themes dir
  holds 10 per-file symlinks: 5 vendored (Catppuccin ×3, Rosé Pine ×2,
  pinned-SHA MIT ports) + 5 shimmed from brew's
  `/opt/homebrew/share/btop/themes/`. `btop.conf` is seeded once from
  `btop.conf.template` (mixed-dir, seed-only), so runtime sort/UI toggles
  don't dirty the repo. Edit the template to change the baked default;
  `current.theme` defaults to `solarized_dark.theme`.
- **`tldr` → `tealdeer`** (follows `theme-set` across all 10 themes; live tier —
  re-reads config each invocation, no reload). Mixed-dir `.config/tealdeer/`:
  per-theme `config-<name>.toml` symlinked, active `config.toml` a machine-local
  symlink flipped by `theme-set`. Four `[style.*]` blocks per theme
  (`command_name` bold, `description`, `example_code`, `example_variable`
  underlined); `example_text` left default. **Colors are `{ rgb = { r,g,b } }`
  tables, not `"#hex"`** — tealdeer 1.8's `[style]` parser rejects hex strings.
  macOS reads `~/Library/Application Support/tealdeer` by default, so
  `00-env.fish` exports `TEALDEER_CONFIG_DIR=~/.config/tealdeer` (absolute;
  eza-style). Sandbox parity via Dockerfile COPY + `.dockerignore` allowlist +
  `stage_theme` floor/overlay. Smoke: `scripts/test-theme-switch.sh`.
- **`ctop` is the container-metrics TUI** (`bcicen/ctop`; raw, no `theme-set`,
  no alias). Live per-container CPU/mem/net/IO; `enter` expands one container.
  Needs a running Docker daemon — OrbStack on this machine; empty table
  otherwise (not a bug). **Out of sandbox scope** (no Docker socket inside the
  container). No config shipped; `S` saves one locally if wanted.
- **`lnav` (raw).** `~/.config/lnav/` real dir; `formats/installed/` whole-dir
  symlinked, `configs/installed/` mixed-dir (tracked theme machinery symlinked,
  active `theme.json` machine-local). `lnav -i` writes to the real dir — `cp`
  new tracked entries into the repo. Don't whole-dir symlink the top dir (#64).
- **`gh dash` (raw; `ghd` abbr).** Mixed-dir `.config/gh-dash/`:
  `config-base.yml` (no `theme:` key) + `theme-colors-<name>.yml` (only the
  `theme:` block). Live `config.yml` is generated by `theme-set` via plain
  `cat` — **don't add `yq`** or a top-level `theme:` to the base (smoke test
  asserts one `^theme:` line). Bootstrap auto-installs the extension. Don't
  re-fragment sections.
- **`lazygit` (git TUI; `<leader>gg` + standalone).** Mixed-dir
  `.config/lazygit/`: `config-base.yml` (delta paging, **no `gui:` key**) +
  `theme-colors-<name>.yml` (only the `gui.theme` block). Live `config.yml`
  is **generated** by `theme-set` via plain `cat base + theme-colors-<name>`
  (gh-dash pattern) — machine-local, never a symlink, never add a `gui:` to
  the base (smoke asserts exactly one `^gui:`). **Restart tier** — lazygit
  reads the theme at launch; relaunch to repaint. **Full 10-theme coverage
  incl. Latte** (catppuccin ships a Latte block), so unlike most followers
  Latte flips rather than degrades. rose-pine/catppuccin vendored upstream
  (MIT); solarized/dracula/gruvbox/tokyo-night/nord derived from
  `.config/themes/<name>.*`. Bootstrap seeds solarized (don't-clobber).
- **`bd` is beads (raw), stealth mode** (`bd init --stealth`): `.beads/` +
  `.claude/settings.local.json` in `.git/info/exclude`, `no-git-ops: true`.
  Re-init only via `--stealth`. **Don't use bd's memory layer** — memory is
  `~/.claude/projects/-Users-martinciu-code-dotfiles/memory/` only. **Don't
  install the `bd prime` SessionStart/PreCompact hooks** (they inject ~1-2k
  tokens contradicting this repo's TodoWrite/auto-memory/PR conventions);
  remove if a prior install left them. Skip `bd setup claude --global`.
- **`diff` → `difft`** (guarded; ad-hoc non-git only — git/vimdiff unaffected).
  Follows the light/dark axis via `DFT_BACKGROUND` (`light` on Latte, `dark`
  elsewhere) + pins `DFT_SYNTAX_HIGHLIGHT=on` — coarse only, no named palette;
  restart tier (new shells). Escape `command diff`. Don't pin flags.
- **`xh` is the HTTP client** (`xh`/`xhs`; `--style=solarized` in
  `.config/xh/config.json`). Don't alias `curl`. No `http`/`https` alias.
- **`jnv` + `fx` are the interactive JSON layer over `jq`.** `jnv` (Rust; embeds
  `jaq`) = jq-filter builder (live preview, key/path autocomplete, keyboard-only);
  `fx` (Go) = JSON navigator (mouse/tree fold/expand) + JS-expr pipe transformer
  (`cat x.json | fx '.a.map(…)'`). **jnv authors filters; fx explores blobs;**
  `jq` stays for scripting. **jnv follows `theme-set`** (live tier): per-theme
  `config-<name>.toml` generated by `scripts/build-jnv-configs.py` (base template
  + tmux `@color_*` palette), machine-local `config.toml` symlink flipped by
  `theme-set`; mixed-dir `.config/jnv/`. macOS jnv reads `~/Library/Application
  Support/jnv` (dirs crate, no env redirect), so `functions/jnv.fish` passes
  `--config ~/.config/jnv/config.toml`; `command jnv` = unthemed escape hatch.
  **`fx` auto-adapts via ANSI palette refs** (default `FX_THEME=1`, pinned in
  `00-env.fish`) like fzf/atuin — no per-theme file; presets 4–9 are fixed
  hex/256 and would follow worse. **Both in sandbox scope** (baked via
  `sandbox/mise.toml`).
- **`slm` pipes any prompt to the local LM Studio model** (fish function
  `.config/fish/functions/slm.fish`; LM Studio-only, Mac-only). One-shot,
  buffered: args and/or stdin → one `curl` POST to `$SLM_URL/chat/completions`
  (default `:1234/v1`, keyless) with `$SLM_MODEL` (default `qwen/qwen3.5-9b`)
  → prints `.choices[0].message.content`. Body pins `reasoning_effort: "none"`
  (qwen3.5 is a hybrid thinking model — without it a one-liner burns thousands
  of reasoning tokens and returns empty content, #363) and `max_tokens`
  (`SLM_MAX_TOKENS`, default 512, numeric-guarded). Uses **`curl`, not `xh`** —
  raw JSON body via `jq`, the documented exception. Flags `-m`/`-s`/`-h`; env
  `SLM_URL`/`SLM_MODEL`/`SLM_SYSTEM`/`SLM_MAX_TOKENS` (precedence flag > env >
  built-in). Server not always-on → friendly `LM Studio not reachable` error
  on connection refusal, no auto-start (start the LM Studio app or `lms server
  start`). Stale-env footgun: a long-lived shell exporting an old `SLM_MODEL`
  gets a `Channel Error` from LM Studio; new shells self-heal. 9B model:
  quick/local, not authoritative. **Out of sandbox scope** (LM Studio is a Mac
  server; in-container `localhost` isn't the host). Smoke:
  `scripts/test-slm.sh`. **Slug-quality eval** for the `i` branch-slug job:
  `scripts/eval-slug.sh` (`--full`/`-n`/`-m`; `SLM_MODEL=… ` to rank a
  candidate) scores slm output against `scripts/eval-slug-fixtures.jsonl` —
  188 real pre-slm merged ccpulse+dotfiles PRs whose `<issue>-<slug>` branch
  is a human-authored gold slug (30 curated `quick:true`); keyword-overlap
  headline + exact + ≤3-word sanity; LM Studio-gated SKIP, never a CI gate.
  The slug pipeline is **shared** in `bin/_slug-from-issue` (sourced by both
  `bin/i` and the eval, so what ships is what's measured).
- **`hyperfine`** for benchmarks (warmups / A-B), additive to `time`. Raw.
- **`duf`/`dust`/`dua` are modern `df`/`du`/`du`-aggregate companions** (raw, no
  alias; `du`/`df` stay for scripts). `dua i` opens a TUI deleter.
- **`lazydocker` (raw).** Container-management TUI (lazygit's Docker sibling).
  Needs a running Docker daemon — **OrbStack** here; inert without one (not
  broken on a fresh machine). No alias; launch by name. Config untracked (runs
  built-in defaults from `~/Library/Application Support/jesseduffield/lazydocker/`);
  `theme-set` theming deferred to the #317 lazygit pattern — redirect to an XDG
  path via the `CONFIG_DIR` env var when it lands. **Out of sandbox scope** (the
  sandbox is itself a container — no Docker socket).
- **Obsidian vault tooling: `basalt` + obsidian.nvim** (vault `~/code/notes`,
  host-only — **out of sandbox scope**). basalt = standalone vault TUI via
  mise `github:erikjuhani/basalt` (`tag_regex="^basalt/"` guards against the
  repo's basalt-core tags; arch-specific `bin_path` — the github backend
  extracts tarballs as-is; tracked `config.toml` — `vim_mode`, nerd-font
  `[symbols]`, `experimental_editor` off — whole-dir symlinked (bootstrap
  `link`, like xh/procs); ANSI-adaptive → follows theme-set free (no
  per-theme file); in-TUI editing stays off — `ctrl+alt+e` spawns vi,
  `ctrl+alt+o` opens the app). obsidian.nvim (community fork) =
  wikilinks/backlinks/pickers in nvim — `plugins/obsidian.lua`, registered
  only when the vault exists, loads only on vault files, buffer-local
  `<leader>o` maps, `ui` off (render-markdown.nvim owns rendering),
  `legacy_commands=false`, no daily notes. Dataview/`.base` stay in the
  Obsidian app.
- **`mmdc` renders Mermaid** (mise global npm tool). `.mmd` + `.svg` co-located,
  both committed. Build: `scripts/build-diagrams.sh`. Don't install via
  brew/`npm -g`.
- **`vhs` renders terminal tapes** (Brewfile; no tapes committed yet). Sources
  `docs/tapes/<name>.tape`, outputs `.gif`+`.webm` alongside, all committed.
  Build: `scripts/build-tapes.sh`. Recording env locked top-of-tape (vhs spawns
  ttyd, not Ghostty).
- **`sandbox` runs untrusted CLI/TUI in an isolated Linux container**
  (`bin/sandbox`, Mac-side; `sandbox/{Dockerfile,mise.toml,install-linux.sh}`).
  Bakes the portable dotfiles subset (Brewfile minus tmux/ruby/procs, plus wt).
  Two modes: **container** (no host mounts — untrusted-safe; rebuilds on
  content-hash mismatch) and **machine** (OrbStack mounts Mac home — trusted
  only). `sandbox create <name>` provisions; bare `sandbox <name>` only attaches
  (errors if absent); `sandbox reup <name> [flags]` recreates with new flags,
  keeping the volume. Secrets injected at runtime (never baked). Build needs
  `GITHUB_TOKEN`. Active Mac theme is baked + re-applied on entry; in-container
  theme *switcher*, tmux, sesh, gh, bd, font-set, vhs out of scope. The sandbox
  starship prompt is the one theme tool whose config is **transformed** when
  generated (not symlinked): `stage_theme` injects a container-gated penguin
  glyph + native git branch/status into a copy of the active
  `starship-<theme>.toml`, so the in-sandbox prompt shows container + git
  context while the Mac's shared tomls stay git-less (#280). `lazygit` also
  follows in-sandbox — `stage_theme` regenerates its `config.yml` by plain
  `cat` (host-identical, no transform). **nvimpager** is the sole non-mise
  sandbox tool —
  `stage_nvimpager` clones it + `make install-no-man` (no prebuilt release
  assets), config copied like nvim's (#283). Smoke: `scripts/test-sandbox.sh`
  (also run in CI: `.github/workflows/sandbox.yml`, arm64, on sandbox-path PRs +
  nightly).

## Where things live

- Sources in `$PROJECTS_HOME/dotfiles/`: `.config/` (whole-dir:
  ccstatusline, procs, tailspin, tmux, xh; mixed-dir: btop (live conf
  seeded from template), eza, fish, gh-dash, ghostty, git (aliases.gitconfig;
  `include.path` in ~/.gitconfig), glow, nvim, worktrunk; `themes/`
  palettes; `starship-*.toml`; partial links for sesh + lnav), `.vimrc`,
  `.vim/colors`, `.gitignore_global`,
  `.claude/CLAUDE.md`. `bin/` files symlink to `~/.local/bin/`.
- The repo's `.claude/CLAUDE.md` IS the user-global Claude config (symlinked to
  `~/.claude/CLAUDE.md`). Edits apply machine-wide.
- Helpers: `.config/tmux/bin/{tmux-git-status,tmux-ssh-indicator,tmux-pr-detect,tmux-status-right}`.

## Cheatsheets (`docs/`)

Three hand-generated Solarized HTML pages
(`nvim-`/`terminal-`/`tmux-cheatsheet.html`). **Update the relevant sheet
whenever config drifts** (footers are dated). Shared styles in `docs/style.css`.
Landing `docs/index.html` serves at https://martinciu.github.io/dotfiles/
(Pages: `main`/`docs`, `.nojekyll`). Screenshots: source
`docs/images/example_<tool>.png` (`tmux|vim|terminal`); derivatives
`-hero`/`-thumb` via `scripts/build-screenshots.sh` — never hand-edit
derivatives, re-run after swapping a source.

## Verify changes

- Helper smoke tests: `scripts/test-helpers.sh`
- Bootstrap linking helpers: `scripts/test-bootstrap-linking.sh`
- Regenerate screenshots: `scripts/build-screenshots.sh`
- Render diagrams: `scripts/build-diagrams.sh`
- Render tapes: `scripts/build-tapes.sh`
- Regenerate theme color page: `scripts/build-theme-colors.py`
- Pre-remove save-shared: `scripts/test-wt-pre-remove-save.sh`
- tmux SSH-indicator: `scripts/test-tmux-ssh-indicator.sh`
- tmux PR-pin: `scripts/test-tmux-pr-status.sh`
- tmux Claude usage: `scripts/test-tmux-claude-usage.sh`
- Moshi auto-attach: `scripts/test-moshi-tmux.sh`
- Moshi theme export: `scripts/test-moshi-theme.sh`
- tmux conf shape: `scripts/test-tmux-conf-shape.sh`
- tmux statusbar guard: `scripts/test-statusbar-guard.sh`
- Session-root binding: `scripts/test-s-session-root.sh`
- Fish config smoke: `scripts/test-fish-loads.sh`
- Ghostty config smoke: `scripts/test-ghostty-config.sh`
- Reapply symlinks (idempotent): `$PROJECTS_HOME/dotfiles/bootstrap.sh`
- Brew deps (installed by bootstrap): `brew bundle check --file=$PROJECTS_HOME/dotfiles/Brewfile --verbose`
- nvim plugin smoke: `scripts/test-nvim.sh`
- Theme switch smoke: `scripts/test-theme-switch.sh`
- Theme/font stats: `scripts/test-theme-font-stats.sh`
- Sandbox smoke: `scripts/test-sandbox.sh`
- nvimpager smoke: `scripts/test-nvimpager.sh`
- slm smoke: `scripts/test-slm.sh`

## First-time setup on a new machine

See [`README.md`](README.md) → "Setup (new machine)".
