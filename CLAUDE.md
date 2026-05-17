# dotfiles — Claude Code instructions

Personal multi-theme, multi-font setup for Ghostty + tmux + vim + fish. `theme-set` swaps between 7 themes (Solarized Dark / Mocha / Frappé / Dracula / Gruvbox / Tokyo Night Storm / Catppuccin Latte) and `font-set` between 17 Nerd Fonts; both switch live. Solarized Dark and JetBrains Mono are the bootstrap defaults. See "Switchable themes" and "Switchable Ghostty fonts" below.

## Conventions — don't drift from these

- **Manual symlinks via `bootstrap.sh`.** No `stow`/`chezmoi`/etc. Tools
  whose `~/.config/<tool>/` dir contains nothing but tracked content get
  whole-dir symlinks (`link "<rel>" "$HOME/..."`). Tools whose dir mixes
  tracked content with machine-local or runtime state (fish, nvim,
  worktrunk, lnav, sesh) use the **mixed-dir pattern** instead: real
  `~/.config/<tool>/` dir, per-file symlinks for tracked entries, real
  files for the rest. Helpers `prepare_real_dir` + `rescue_in_repo` +
  `link_tracked_entries` + `seed_local` implement the pattern;
  `link_tracked_entries` skips `*.template` files. Migration from a
  legacy whole-dir symlink is automatic on next `bootstrap.sh` run.
- **Bash scripts target bash 5.** Shebang `#!/opt/homebrew/bin/bash`; may
  use `mapfile`, `declare -A`, `wait -n`. Apple Silicon only — `brew
  bundle` runs before `bootstrap.sh`. Don't reintroduce bash-3 shims.
- **Fish module layout.** Fish is the primary interactive shell. Config
  in `.config/fish/`. `~/.config/fish/` is a real dir (mixed-dir pattern):
  `config.fish` and `functions/` are symlinked from the repo. `conf.d/`
  is itself a real dir with per-file symlinks for the tracked `*.fish`
  modules and **real files** for `15-local.fish` + `99-secrets.fish`
  (seeded from `.template` companions on first bootstrap, untouched
  after). `completions/` is also a real dir: tracked `s.fish` and
  `wt.fish` are symlinked from the repo, and machine-specific
  completions (fish's man-page auto-generation, OrbStack's `kubectl`/
  `orbctl`, etc.) live as real files alongside, never entering the
  repo. `fish_variables`, `fish_history`, `generated_completions/` are
  real and stay outside the repo.
  `config.fish` is empty; concerns in `conf.d/<NN>-<concern>.fish`,
  numeric prefix pins load order:
  `00-env`, `10-colors`, `15-local` (per-machine, untracked), `20-mise`,
  `25-prompt` (starship), `30-aliases`,
  `35-abbreviations` (git-flow mnemonic abbrs — `gst`, `gco`, `gp`, …),
  `40-plugins` (fzf, zoxide, wt, Polish-diacritic Alt-C unbind),
  `99-secrets` (untracked). The two untracked files are copied from
  `.template` companions by `bootstrap.sh`. `functions/less.fish`
  is a bat-backed `less` wrapper; `completions/wt.fish` adds wt
  tab-completion. Smoke test: `scripts/test-fish-loads.sh`.
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
  (main-checkout git chip on the right + 7d Claude-usage chip on the
  left), yellow (worktree git chip on the right + 5h Claude-usage chip
  on the left), orange (PR pin, left of git chip). When adding a pin,
  pick from unused accents (red, magenta, cyan); reconsider if all are
  taken. **Palette reuse across the left and right clusters is
  permitted** — the usage cluster's violet and yellow slots are
  positional, not paired with anything on the right. Two violets or
  two yellows visible simultaneously is the by-design behavior, not a
  clash. Mode-style, message-style, pane-borders, and inline text
  colors (e.g. ins/del markers in `tmux-git-status`) are not pins.
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
- **tmux Claude usage cluster** wired into `status-left` via
  `#(~/.config/tmux/bin/tmux-claude-usage)`. Parses
  `ccpulse status --json` on each 5 s tick (~33 ms; no bash-level
  cache) and emits two fused chips: violet 7d weekly
  (`<robot> <calendar> <pct>%`, auto-expands to
  `<robot> <calendar> <pct>% • <reset>` when `pct >= 80`) and yellow
  5h block (`<hourglass> <pct>% • <reset>`, always full). Glyphs:
  `<robot>` is U+1F916 emoji (chosen over the Nerd Font `nf-fa-robot`
  U+F544 for portability), `nf-fa-hourglass-half` (U+F252),
  `nf-oct-calendar` (U+F455), and `nf-fa-fire` (U+F06D — overreach
  decoration). Arrow caps: left-rounded on the violet chip's left
  edge against `bar_bg`, all others forward-facing. **Overreach
  decoration:** when `projection.<window>.will_overreach == true`,
  the affected chip inserts ` <fire> → <projected_pct>%` after its
  `<pct>%`, before any bullet+reset suffix. The 7d chip auto-expands
  on overreach even when `pct < 80` (showing `<pct>% <fire> →
  <projected>%` with no reset). Each chip evaluates its window
  independently; one can warn while the other stays normal. No
  confidence gating — `will_overreach` is trusted directly.
  Graceful degradation: missing `projection` field (older ccpulse) or
  null `projected_pct_at_reset` does not hide the cluster — the chip
  renders without the decoration (or with the fire glyph alone, when
  `will_overreach=true` but `projected_pct_at_reset=null`). Atomic
  hide still applies to the four core fields (`percent`,
  `minutes_to_reset`, `quota.seven_day.utilization`,
  `quota.seven_day.resets_at`) — when any of those is missing, the
  whole cluster hides. `status-left-length` bumped 80 → 120 to fit.
  The cluster's violet/yellow palette is positional and independent
  of the right-side git chips' palette — see the palette-reuse note
  in the unique-accent rule.
- **tmux prefix is `C-a`** (`C-Space` conflicts with macOS input-source
  switching). Pane nav: `<prefix> h/j/k/l` (Alt is reserved for Polish
  diacritics — never `bind -n M-*`). Splits: `|` and `-`.
- **tmux-fingers gives one-keystroke copy of visible matches.**
  TPM plugin `Morantron/tmux-fingers`. Bindings: `<prefix> F` enters
  copy-mode (hint letter → match copied to clipboard via `pbcopy`),
  `<prefix> J` enters jump-mode (hint letter → cursor at match inside
  copy-mode). Default per-modifier actions in hint mode: `Ctrl+letter`
  = open (URL → browser, path → Finder), `Shift+letter` = paste into
  pane, `Tab` = multi-select. **No `bind -n M-*` recipes** from the
  README — Alt stays reserved for Polish diacritics.
  Hint colors use ANSI palette refs (`colour9`/`colour10`/`colour13`/
  `colour14`) so they auto-adapt across all seven themes via Ghostty's
  16-color palette — no per-theme variant files, same trick as
  `FZF_DEFAULT_OPTS`. Custom patterns added on top of the built-ins:
  `worktree-[a-z0-9._/-]+` (worktree branch names) and `#\d+` (PR/issue
  refs). Built-ins kept on: `ip`, `uuid`, `sha`, `digit`, `url`, `path`,
  `hex`, `kubernetes`, `git-status`, `git-status-branch`, `diff`.
  **Fresh-machine setup:** after `prefix + I`, the first-run wizard
  appears — pick "Build from source" (crystal must be on `$PATH`; install
  via `brew install crystal` if absent). Why no `brew "tmux-fingers"` in
  Brewfile: the morantron tap also compiles Crystal from source, so the
  wizard fires either way — declaring it gains nothing over documenting
  the one-liner here.
- **TPM is the tmux plugin manager.** Loaded: `tmux-sensible`,
  `tmux-resurrect`, `tmux-continuum` (`@continuum-restore 'on'`),
  `tmux-sessionx`, `tmux-fingers`. Status bar is hand-rolled, behavior
  plugins aren't — don't remove TPM.
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
- **`vim`/`vimdiff` are fish aliases to nvim**; **`vi` is `command vim`**
  (legacy minimal vim). All guarded on `command -v nvim`. Minimal vim
  (`.vimrc` ~30 lines, `.vim/colors/solarized8.vim`) is reachable via
  `vi`/`command vim`/`\vim`. Don't add vim-plug or LSP to it.
- **nvim is built on LazyVim**, themed Solarized, configured at
  `.config/nvim/`. Don't replace LazyVim. `~/.config/nvim/` is a real
  dir (mixed-dir pattern): `init.lua`, `mason-lock.json`, `lua/` are
  symlinked from the repo; `lazy/`, `mason/`, `site/`, `lazyvim.json`,
  `lazy-lock.json` are real and stay outside the repo.
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
  Only `mason-lock.json` is tracked; `lazy-lock.json` is gitignored
  — Lazy auto-updates churn it on every plugin update and the diffs
  were noise, not signal. Run `:Lazy restore` against the working
  tree's own lockfile when you need reproducibility on a single
  machine.
- **Switchable themes — Solarized Dark ↔ Catppuccin Mocha ↔ Catppuccin Frappé ↔ Dracula ↔ Gruvbox ↔ Tokyo Night Storm ↔ Catppuccin Latte.**
  Solarized Dark is the canonical default. Catppuccin Latte is the **first
  and only light theme** and ships with **partial tier-1 coverage**: only
  Ghostty, tmux, and starship have Latte variants — delta, glow, gh-dash,
  lnav, and nvim keep their previous (dark) theme during a Latte session
  by design. This is enforced by existence-guarded `test -f` checks inside
  `theme-set.fish` rather than a bespoke `case latte` branch — future
  tier-1 extensions are purely additive (drop a variant file in, the guard
  auto-engages, no `theme-set` changes). Issue #215 tracks the
  full-coverage follow-up. `theme-set <name>` (fish function in
  `.config/fish/functions/`) flips active-theme symlinks across the
  hot-path + file-viewer tools. Palette files live in `.config/themes/`
  (mixed-dir: tracked `*.tmux` palettes + tracked `delta-*.gitconfig`;
  machine-local `current.tmux` and `delta-current.gitconfig` symlinks).
  Per-tool variant files use the naming convention `*-solarized.<ext>`
  / `*-mocha.<ext>` / `*-dracula.<ext>` / `*-gruvbox.<ext>` /
  `*-tokyo-night.<ext>` / `*-latte.<ext>` (where present — Latte is
  partial-coverage, see above) and live alongside their tool's config —
  `.config/ghostty/theme-{solarized,mocha,dracula,gruvbox,tokyo-night,latte}.ghostty`,
  `.config/glow/glamour-{solarized,mocha,dracula,gruvbox,tokyo-night}.json`,
  `.config/gh-dash/theme-colors-{solarized,mocha,dracula,gruvbox,tokyo-night}.yml`
  (alongside the shared `.config/gh-dash/config-base.yml`),
  `.config/lnav/configs/installed/theme-{solarized,mocha,dracula,gruvbox,tokyo-night}.json`,
  `.config/starship-{solarized,mocha,dracula,gruvbox,tokyo-night,latte}.toml`. The active
  variant is picked via a machine-local symlink at the tool's normal
  config path. gh-dash is the one exception: its live `config.yml` is a
  generated real file (`cat config-base.yml theme-colors-<name>.yml > config.yml`)
  because gh-dash doesn't support YAML includes or anchor-merging — see
  the dedicated `gh dash` bullet below. tmux uses `@color_*` user options (set in the palette
  file, sourced by `tmux.conf` via
  `source-file -F '#{HOME}/.config/themes/current.tmux'`) read by both
  `tmux.conf` (`#{@color_*}` interpolation) and helper scripts
  (`tmux show-option -gv`, with Solarized hex fallback for the test
  harness path). Bat uses `$BAT_THEME` and vivid (`LS_COLORS` for
  `ls`/`eza` file-type colors) uses `$VIVID_THEME`, both set as fish
  universal vars by `theme-set`. bat 0.26+ ships Catppuccin Mocha,
  Dracula, and `gruvbox-dark` built-in (no vendoring) — but does
  NOT ship a Tokyo Night syntax theme, so `theme-set tokyo-night`
  falls back to `Catppuccin Mocha` for `$BAT_THEME` (closest
  pastel-on-dark in bat's catalogue; no `bat cache --build`
  bootstrap step needed). vivid 0.11+ ships all five
  (`solarized-dark`, `catppuccin-mocha`, `dracula`, `gruvbox-dark`,
  `tokyonight-storm`). `.config/fish/conf.d/10-colors.fish` reads
  `$VIVID_THEME` at fish startup to regenerate LS_COLORS. fzf colors
  (Ctrl-R history, Ctrl-T file picker) use ANSI palette refs (0–15,
  `-1` = terminal default) in `FZF_DEFAULT_OPTS` — auto-adapt to
  whatever Ghostty's 16-color palette is, no per-theme switch
  needed. Frappé sits between Mocha and Latte on the Catppuccin spectrum (base
  `#303446`, lifted vs Mocha's `#1e1e2e`). Uses dark-on-pastel chip text
  like Mocha (`@color_light_fg = "#232634"` = Frappé crust). Starship
  `pastel_rose` is **mauve `#ca9ee6`** (deliberate divergence from Mocha's
  pink — Catppuccin's headline accent gives Frappé its own visual
  identity). bat 0.26+ ships `Catppuccin Frappé` built-in; vivid 0.11+
  ships `catppuccin-frappe`; Ghostty 1.0+ ships the preset; the vendored
  `lnav/configs/installed/catppuccin.json` already defines
  `catppuccin-frappe` (no extra vendoring). The `catppuccin/nvim` plugin
  (already installed for Mocha) provides the `catppuccin-frappe`
  colorscheme.
  Dracula uses dark-on-pastel chip text too
  (`@color_light_fg = "#282a36"`), matching Mocha's inversion rather
  than Solarized's light-on-saturated. Dracula has no pure blue
  accent: `@color_accent_blue` reuses the comment hex `#6272a4`,
  intentionally colliding with `@color_muted_fg` — Dracula-faithful,
  and no current tmux pin uses `accent_blue`. Gruvbox Dark Medium
  uses dark-on-accent chip text too (`@color_light_fg = "#282828"` =
  Gruvbox bg0). Gruvbox has one canonical purple, so
  `@color_accent_magenta` and `@color_accent_violet` resolve to the
  same hex (`#b16286`) — faithful to the palette; no current tmux
  pin distinguishes the two roles. Tokyo Night Storm uses
  dark-on-accent chip text too (`@color_light_fg = "#24283b"` =
  Storm bg), matching the Gruvbox/Mocha/Dracula inversion. Tokyo
  Night has one canonical purple, so `@color_accent_magenta` and
  `@color_accent_violet` resolve to the same hex (`#bb9af7`) —
  palette-faithful; no current tmux pin distinguishes the two
  roles. **lnav 0.14 does not ship
  gruvbox**, so `.config/lnav/configs/installed/gruvbox.json` is a
  vendored theme-defs (modelled on the Catppuccin vendor, hex codes
  from `morhetz/gruvbox` MIT). Hard / Soft contrast and Light
  variants are out of v1. **lnav 0.14 also does not ship Tokyo
  Night**, so `.config/lnav/configs/installed/tokyo-night.json` is a
  second vendored theme-defs (same shape as `gruvbox.json`, hex from
  `folke/tokyonight.nvim` MIT). Night / Moon / Day variants of Tokyo
  Night are out of v1. **Catppuccin Latte is the first light theme**
  and inverts a few assumptions baked into the dark-only collection:
  bar bg is mantle `#e6e9ef` (not a dark surface), and tmux chips
  use **light-on-saturated** chip text (`@color_light_fg = "#eff1f5"`)
  while starship uses **dark-on-pastel**
  (`base3 = "#4c4f69"`) — different chip-bg palettes drive different
  inversion choices. Latte ships only ghostty/tmux/starship + bat/vivid
  env vars; delta/glow/gh-dash/lnav/nvim stay on the previous
  (dark) theme during a Latte session. bat 0.26+ ships
  `Catppuccin Latte` built-in; vivid 0.11+ ships
  `catppuccin-latte`; Ghostty 1.0+ ships the preset.
  Delta is included from `~/.gitconfig` via
  `[include] path = ~/.config/themes/delta-current.gitconfig` (one-time
  setup, see README). nvim picks its colorscheme at startup via the
  resolver in `lua/config/theme.lua` (reads `readlink` of
  `current.tmux`); the `catppuccin/nvim`, `Mofiqul/dracula.nvim`,
  `ellisonleao/gruvbox.nvim`, and `folke/tokyonight.nvim` plugins
  are installed alongside `maxmx03/solarized.nvim`. Bootstrap's
  "don't clobber" guards preserve any prior `theme-set mocha`,
  `theme-set dracula`, `theme-set gruvbox`, or `theme-set
  tokyo-night` pick across re-runs. Out of v1:
  `btop`/`procs`/`tailspin`/`xh`/`ccstatusline`, cheatsheet
  HTML toggle, screenshot regeneration, live nvim retheme.
- **Switchable Ghostty fonts — 17 Nerd Fonts, optional weight + size.**
  JetBrains Mono is the default. Six with ligatures: `jetbrains`,
  `fira`, `cascadia` (ships as `CaskaydiaCove`), `monaspace` (Neon
  variant, ships as `Monaspice`), `iosevka`, `0xproto`. Five
  classics, no ligatures: `hack`, `meslo` (MesloLGS, Powerlevel10k's
  default), `sauce` (Source Code Pro, ships as `SauceCodePro`),
  `ubuntu` (UbuntuMono), `inconsolata`. Six retro / specialty, no
  ligatures: `departure` (DepartureMono, 2024 pixel display),
  `bigblue` (BigBlueTermPlus, IBM CP437 pixel bitmap), `3270` (IBM
  3270 mainframe terminal; Cond/SemCond width variants ship but
  aren't wired up — flip by hand if needed), `hurmit` (Hermit,
  Nerd Fonts rename), `monofur` (hand-drawn curves), `dyslexic`
  (OpenDyslexicM — weighted-bottom glyphs for dyslexic readers; the
  cask also ships an "Alt" family with more weights, only Mono is
  wired up). `font-set <name> [<weight>] [<size>]`
  (fish function) flips a machine-local symlink
  `~/.config/ghostty/font.ghostty` → one of the per-font include files
  (each a one-liner `font-family = ...`). When `<weight>` is given
  (must match a style the font actually advertises — see
  `__font_set_weights_for` for the per-font list), it rewrites
  `~/.config/ghostty/font-weight.ghostty` with `font-style = <weight>`.
  When `<size>` is given (positive int or decimal, e.g. `14`, `13.5`),
  it rewrites the machine-local real file
  `~/.config/ghostty/font-size.ghostty` with `font-size = <size>`.
  Omit either to keep the current value. Weight comes before size
  because it changes more often than size in practice.
  `config.ghostty` pulls family + size + weight via three `config-file
  = ...` directives; `font-thicken` stays there (shared across fonts).
  `ghostty +reload` fires live. All seventeen casks are pinned in `Brewfile`.
  Bootstrap seeds `font-size.ghostty` at `font-size = 14` and
  `font-weight.ghostty` as a comment-only file (so Ghostty falls back
  to each font's own Regular) on first run; "don't clobber" guards
  preserve any prior `font-set` pick across re-runs. Per-font weight
  lists live in the fish helper `__font_set_weights_for.fish` (sourced
  by both validation and 3rd-arg completion), populated from
  `ghostty +list-fonts` — FiraCode is the odd one out, advertising
  abbreviated style names (`Reg`, `Med`, `SemBd`, `Ret`); the four
  single-weight fonts (`departure`, `bigblue`, `3270`, `dyslexic`)
  advertise `Regular` only, so the weight arg is effectively cosmetic
  for them. Add a new font: drop a new `font-<short>.ghostty` next to
  the others, append the cask to `Brewfile`, extend the `switch` in
  `font-set.fish` + its 1st-arg completion + `__font_set_weights_for`.
  No nvim/tmux/bat coupling — font is a Ghostty-only concern.
- **Starship pastel accent — per theme.** Solarized keeps the
  `#DA627D` rose; Mocha uses `#f5c2e7` (pink, Catppuccin's canonical
  "personal" accent); Dracula uses `#ff79c6` (Dracula pink). Defined
  in each starship config's
  `[palettes.<name>]` block as `pastel_rose`. Chip is flush-left, ends
  with U+E0B4 rounded right cap; prompt char drops to line 2. Single
  chip because starship silently drops `bg:` when both `fg:` and `bg:`
  reference custom palette names in the top-level format. Don't extend
  pastel to other tools; don't add `(fg:custom_a bg:custom_b)` chips.

  Fish opts into Starship's transient prompt: after Enter, the active
  chip is replaced with a bold `❯`; `cmd_duration`/`status` stay intact.
  Wired via `enable_transience` from `.config/fish/conf.d/25-prompt.fish`.
  Starship 1.25.x has no `[transient_prompt]` section — don't add one
  (silently ignored, trips `[WARN]`).
- **wt user config is symlinked from `.config/worktrunk/config.toml`.**
  `~/.config/worktrunk/` is a real dir (mixed-dir pattern): `config.toml`
  is the only symlink; per-project `approvals.toml` is a real file there,
  outside the repo working tree.
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
- **Bells silenced at every layer:** Ghostty `bell-features =`, vim
  `belloff=all`, tmux `bell-action/visual-bell/monitor-bell off`. Fish
  has no BEEP option; any `\a` is consumed at Ghostty/tmux. Don't
  re-enable.
- **Terminal tools default to Solarized Dark; some follow `theme-set`.**
  Follow `theme-set`: `bat` (via `$BAT_THEME`), `git-delta` (via
  `delta-current.gitconfig` include), `glow` / `md` (via `glamour.json`
  symlink), `vivid` / `LS_COLORS` (via `$VIVID_THEME`, read by
  `.config/fish/conf.d/10-colors.fish`), fzf (palette-symbolic refs in
  `FZF_DEFAULT_OPTS`, auto-adapts via Ghostty's 16-color palette).
  Stay Solarized-only: `procs` (`ps`), `tailspin` (`tspin`), `xh`. Pins:
  `bat --theme="Solarized (dark)"` is the fallback when `$BAT_THEME` is
  unset; `procs` reads `.config/procs/procs.toml`, `md` passes
  `--style .config/glow/glamour.json`, `tspin` reads
  `.config/tailspin/theme.toml` (ANSI names; severity keywords
  `error`/`warn`/`info`/`debug` as `[[keywords]]`). No `tail` alias —
  `tspin file.log` / `cmd | tspin -p` stay explicit. Don't introduce
  alternatives (`exa`, `lsd`, `diff-so-fancy`, `mdcat`).

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
  `.config/fish/functions/less.fish`). Files get bat decoration; piped
  input uses `--plain` (so stdin doesn't get bat's `STDIN` header).
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
- **`lnav` is the TUI log navigator** (raw command, no alias).
  `~/.config/lnav/` is a real dir. `formats/installed/` stays
  whole-dir-symlinked to the repo (no machine-local entries needed
  there — `inngest.json` is the one tracked format, for `inngest-cli
  dev` JSON-per-line stdout). `configs/installed/` is **mixed-dir**:
  tracked theme machinery (`catppuccin.json` — vendored Catppuccin
  theme-defs from `ninetailedtori/catppuccin-lnav`, MIT — plus
  `theme-{solarized,mocha}.json` selectors that set `ui.theme`) is
  per-file symlinked; the active `theme.json` is a machine-local
  symlink swapped by `theme-set`. Side effect: `lnav -i` writes into
  the real machine-local `configs/installed/` dir, not the repo — `cp`
  new tracked entries into the repo explicitly. lnav owns the rest of
  `~/.config/lnav/` (samples, `crash/`, `staging/`, `log_metadata.db`,
  `view-info-*.json`, `config.json`). Don't re-introduce a whole-dir
  symlink on the top-level dir (issue #64).
- **`gh dash` is the GitHub TUI** (raw command; `ghd` abbr in
  `35-abbreviations.fish`). Mixed-dir layout under `.config/gh-dash/`:
  `config-base.yml` holds the shared schema (sections, defaults, layout,
  pager, etc., **no `theme:` key**), and `theme-colors-{solarized,mocha,
  dracula,gruvbox,tokyo-night}.yml` each hold *only* the top-level `theme:`
  block (both `colors` and the small `ui` block — `ui` duplicates 5× and
  that's accepted, since YAML can't merge two `theme:` keys after
  concatenation). PR section is a single `Open` view (`is:open`); issues
  has `Open` (`is:open`) + `v0.1.0` (`is:open milestone:"v0.1.0"`); don't
  re-fragment by author/reviewer/assignee. The active
  `~/.config/gh-dash/config.yml` is a **generated real file**, not a
  symlink — `theme-set <name>` writes it via
  `cat config-base.yml theme-colors-<name>.yml > config.yml`. Plain
  `cat` works because the base has no `theme:` key; **don't add `yq` or
  a merge engine**. Don't introduce a top-level `theme:` into
  `config-base.yml`; the smoke test (`scripts/test-theme-switch.sh`)
  catches that by asserting exactly one `^theme:` line in the generated
  file. `bootstrap.sh` seeds the live `config.yml` on first run only
  (Solarized default; subsequent runs preserve a prior `theme-set`
  pick) and removes legacy `config-<name>.yml` symlinks from the
  pre-dedup shape. Bootstrap auto-installs the extension idempotently
  (`gh extension list | grep -q '^gh dash'` guard); install failure
  prints a warning, doesn't abort. No `gh auth` required — `gh extension
  install` clones a public repo. Color mapping stays standard base16
  (`text.primary` = base0, `background.selected` = base02, etc.).
  If gh-dash ever starts writing cache/state inside
  `~/.config/gh-dash/`, the mixed-dir pattern already accommodates it
  (`link_tracked_entries` only touches tracked files).
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
  multiple runs, A/B. Don't alias or wrap.
- **`duf` is a modern `df` companion** (raw, no alias). Grouped output by
  device class (local/network/special/fuse), color-coded usage bars, theme-
  aware (auto-detects dark; `--theme dark` pins it). `df` stays for scripts
  and POSIX habit; `duf` for interactive disk-free checks. Don't alias or
  wrap.
- **`dust` is a modern `du` companion** (raw, no alias). Tree-style output
  sorted largest-first, colored bar graphs per node, depth-aware (`-d N`
  to limit). Read-only inspection — fast parallel scan, zero side effects.
  `du` stays for scripts and POSIX habit; `dust` for "where did my disk
  go?" at-a-glance. Don't alias or wrap.
- **`dua` is a fast `du` aggregate with an interactive TUI deleter** (raw,
  no alias). Plain `dua [path]` walks the tree in parallel and prints
  aggregate sizes; `dua i [path]` opens a TUI for navigating, marking, and
  *deleting* directories. `du` stays for scripts and POSIX habit; `dua`
  for fast aggregates and interactive disk reclaim. Don't alias or wrap.
- **`mmdc` renders Mermaid diagrams** (`@mermaid-js/mermaid-cli`), installed
  via mise as a global npm tool (`mise.global.toml`). `.mmd` source files
  live co-located with the docs that reference them; rendered `.svg` files
  sit alongside (same directory, same basename). Both are committed.
  Build all: `scripts/build-diagrams.sh`. Single file:
  `mmdc -i file.mmd -o file.svg`. Don't install via brew (parallel node
  stack) or `npm install -g` (not declarative, lost on node upgrade).

## Where things live

- Sources in `$PROJECTS_HOME/dotfiles/`: `.config/` (whole-dir per tool:
  `btop`, `ccstatusline`, `procs`, `tailspin`, `tmux`, `xh`; mixed-dir
  per tool: `fish`, `gh-dash`, `ghostty`, `glow`, `nvim`, `worktrunk`;
  themes dir: `themes/` (palette files + delta snippets); plus
  `starship-{solarized,mocha,dracula,gruvbox,tokyo-night}.toml`, partial links for `sesh/sesh.toml`
  and `lnav/configs/installed` (mixed-dir) +
  `lnav/formats/installed` (whole-dir)),
  `.vimrc`, `.vim/colors`, `.gitignore_global`, `.claude/CLAUDE.md`.
  `bin/` files symlink to `~/.local/bin/`.
- The repo's `.claude/CLAUDE.md` IS the user-global Claude config
  (symlinked to `~/.claude/CLAUDE.md`). Edits apply machine-wide.
- Helpers: `.config/tmux/bin/{tmux-git-status,tmux-ssh-indicator,tmux-pr-detect,tmux-status-right}`.

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
- Render diagrams: `scripts/build-diagrams.sh`
- Pre-remove save-shared: `scripts/test-wt-pre-remove-save.sh`
- tmux SSH-indicator: `scripts/test-tmux-ssh-indicator.sh`
- tmux PR-pin: `scripts/test-tmux-pr-status.sh`
- tmux Claude usage: `scripts/test-tmux-claude-usage.sh`
- Session-root binding: `scripts/test-s-session-root.sh`
- Fish config smoke: `scripts/test-fish-loads.sh`
- Reapply symlinks (idempotent): `$PROJECTS_HOME/dotfiles/bootstrap.sh`
- Brew deps (installed by bootstrap): `brew bundle check --file=$PROJECTS_HOME/dotfiles/Brewfile --verbose`
- nvim plugin smoke: `scripts/test-nvim.sh`
- Theme switch smoke: `scripts/test-theme-switch.sh`

## First-time setup on a new machine

See [`README.md`](README.md) → "Setup (new machine)".
