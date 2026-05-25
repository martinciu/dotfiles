#!/opt/homebrew/bin/bash
# bootstrap.sh — idempotent dotfiles installer.
# Re-running is safe: every step checks "already done" and skips.
set -euo pipefail

DOTFILES="$PROJECTS_HOME/dotfiles"

echo "🚀 dotfiles bootstrap"

# --- brew (install missing formulae; abort on failure)
echo
echo "🍺 brew bundle install:"
brew bundle --file="$DOTFILES/Brewfile"

# link <source-relative-to-DOTFILES> <target-absolute>
link() {
  local src="$DOTFILES/$1"
  local dst="$2"
  if [ ! -e "$src" ]; then
    echo "❓  $src (skipping)"
    return 0
  fi
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "✅  $dst"
    return 0
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="$dst.bak.$(date +%s)"
    echo "📦  $dst → $backup"
    mv "$dst" "$backup"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  echo "🔗  $dst → $src"
}

# prepare_real_dir <target-abs-dir>
#   Tears down a legacy whole-dir symlink at <target> if present, then
#   ensures <target> exists as a real directory. Idempotent.
prepare_real_dir() {
  local dst="$1"
  if [ -L "$dst" ]; then
    rm "$dst"
    echo "🗑️  $dst (legacy whole-dir symlink)"
  fi
  mkdir -p "$dst"
}

# rescue_in_repo <repo-abs-path> <target-abs-path>
#   Migration aid for machines that ran an older bootstrap where the dir
#   was whole-dir-symlinked. If <repo-abs-path> exists as a real file or
#   dir (not a symlink), and <target-abs-path> doesn't yet, MOVE it across.
#   Idempotent: no-op once rescued. Must run AFTER prepare_real_dir on
#   the parent so the destination path is no longer aliased to the repo.
rescue_in_repo() {
  local in_repo="$1"; local new_home="$2"
  if [ -e "$in_repo" ] && [ ! -L "$in_repo" ] && [ ! -e "$new_home" ]; then
    mkdir -p "$(dirname "$new_home")"
    mv "$in_repo" "$new_home"
    echo "🚚  $in_repo → $new_home"
  fi
}

# link_tracked_entries <repo-rel-source-dir> <target-abs-dir>
#   Per-entry symlinks every tracked top-level entry from <source> into
#   <target>, skipping *.template files. Tracked entries that are dirs
#   are whole-dir-symlinked; tracked files are file-symlinked. Reuses the
#   existing link() helper, so already-correct symlinks no-op. Entries
#   whose destination already exists as a real (non-symlink) dir are
#   left alone — that means the caller is handling them recursively
#   (e.g. fish/conf.d/ inside fish/) and link() would otherwise back up
#   the real dir and replace it with a symlink.
link_tracked_entries() {
  local src_rel="$1"; local dst="$2"
  local src="$DOTFILES/$src_rel"
  for entry in "$src"/*; do
    [ -e "$entry" ] || continue
    local name; name="$(basename "$entry")"
    case "$name" in *.template) continue ;; esac
    if [ -d "$entry" ] && [ -d "$dst/$name" ] && [ ! -L "$dst/$name" ]; then
      continue
    fi
    link "$src_rel/$name" "$dst/$name"
  done
}

# seed_local <template-repo-rel> <target-abs>
#   First-run copy of a .template into a real file on disk. Idempotent:
#   no-op if the target already exists.
seed_local() {
  local tmpl="$DOTFILES/$1"; local dst="$2"
  if [ ! -f "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$tmpl" "$dst"
    echo "✨  $dst (seeded from $(basename "$tmpl"))"
  fi
}

# --- ghostty
# ~/.config/ghostty/ is a real dir; tracked entries are individually
# symlinked. Active-theme and active-font symlinks (theme.ghostty,
# font.ghostty) are machine-local — created only if missing so prior
# `theme-set` / `font-set` picks survive re-running bootstrap.
prepare_real_dir "$HOME/.config/ghostty"
link_tracked_entries ".config/ghostty" "$HOME/.config/ghostty"
[ -L "$HOME/.config/ghostty/theme.ghostty" ] \
    || ln -sfn theme-solarized.ghostty "$HOME/.config/ghostty/theme.ghostty"
[ -L "$HOME/.config/ghostty/font.ghostty" ] \
    || ln -sfn font-jetbrains.ghostty "$HOME/.config/ghostty/font.ghostty"
[ -f "$HOME/.config/ghostty/font-size.ghostty" ] \
    || echo 'font-size = 14' > "$HOME/.config/ghostty/font-size.ghostty"
[ -f "$HOME/.config/ghostty/font-weight.ghostty" ] \
    || echo '# Weight (font-style) written by `font-set <name> _ <weight>`' \
       > "$HOME/.config/ghostty/font-weight.ghostty"

# --- tmux
link ".config/tmux"    "$HOME/.config/tmux"

# --- themes (Solarized Dark + Catppuccin Mocha; switchable via theme-set)
# ~/.config/themes/ is a real dir; tracked palette files individually
# symlinked. Active-theme symlinks (current.tmux, delta-current.gitconfig)
# are machine-local — created only if missing so a prior `theme-set` pick
# survives re-running bootstrap.
prepare_real_dir "$HOME/.config/themes"
link_tracked_entries ".config/themes" "$HOME/.config/themes"
[ -L "$HOME/.config/themes/current.tmux" ] \
    || ln -sfn solarized.tmux "$HOME/.config/themes/current.tmux"
[ -L "$HOME/.config/themes/delta-current.gitconfig" ] \
    || ln -sfn delta-solarized.gitconfig "$HOME/.config/themes/delta-current.gitconfig"

# --- ccstatusline
link ".config/ccstatusline" "$HOME/.config/ccstatusline"

# --- worktrunk
# ~/.config/worktrunk/ is a real dir; tracked entries are individually symlinked.
# Per-project approvals.toml stays outside the repo.
prepare_real_dir "$HOME/.config/worktrunk"
rescue_in_repo "$DOTFILES/.config/worktrunk/approvals.toml" \
               "$HOME/.config/worktrunk/approvals.toml"
link_tracked_entries ".config/worktrunk" "$HOME/.config/worktrunk"

# --- git
# ~/.config/git/ is a real dir (often holds a machine-local `ignore`); the
# tracked aliases.gitconfig is individually symlinked. Pulled into git via an
# include.path line in ~/.gitconfig (see README → Setup), mirroring delta.
prepare_real_dir "$HOME/.config/git"
link_tracked_entries ".config/git" "$HOME/.config/git"

# --- glow
# ~/.config/glow/ is a real dir; tracked entries (glamour-{solarized,mocha}.json)
# are individually symlinked. Active glamour.json is a machine-local symlink.
prepare_real_dir "$HOME/.config/glow"
link_tracked_entries ".config/glow" "$HOME/.config/glow"
[ -L "$HOME/.config/glow/glamour.json" ] \
    || ln -sfn glamour-solarized.json "$HOME/.config/glow/glamour.json"

# --- tailspin (tspin) — Solarized theme.toml
link ".config/tailspin" "$HOME/.config/tailspin"

# --- btop
link ".config/btop"    "$HOME/.config/btop"

# --- procs (modern ps; Solarized config + procs-heavy.toml for `psh`)
link ".config/procs"   "$HOME/.config/procs"

# --- xh (modern HTTP client; Solarized via default_options)
link ".config/xh"      "$HOME/.config/xh"

# --- nvimpager (neovim as $PAGER; smooth + colored paging for glow)
# ~/.config/nvimpager/ holds only the tracked init.lua; nvimpager's runtime
# state lives under ~/.local/share/nvimpager/, so a whole-dir symlink is safe.
link ".config/nvimpager" "$HOME/.config/nvimpager"

link ".config/atuin"   "$HOME/.config/atuin"

# --- gh-dash (TUI for PRs/issues/notifications; switchable theme)
# ~/.config/gh-dash/ is a real dir. Shared schema lives in config-base.yml;
# per-theme palettes live in theme-colors-<name>.yml. Both are tracked and
# individually symlinked. The active config.yml is a machine-local real
# file generated by `theme-set` via `cat base theme-colors-<name>.yml > config.yml`.
prepare_real_dir "$HOME/.config/gh-dash"

# Migration from the pre-dedup shape: remove the old per-theme monoliths
# (config-<name>.yml are now dangling symlinks) and any config.yml that
# was a symlink to one of them.
for stale in config-solarized.yml config-mocha.yml config-dracula.yml \
             config-gruvbox.yml config-tokyo-night.yml; do
    if [ -L "$HOME/.config/gh-dash/$stale" ]; then
        rm "$HOME/.config/gh-dash/$stale"
        echo "🗑️  $HOME/.config/gh-dash/$stale (legacy monolith symlink)"
    fi
done
if [ -L "$HOME/.config/gh-dash/config.yml" ]; then
    rm "$HOME/.config/gh-dash/config.yml"
    echo "🗑️  $HOME/.config/gh-dash/config.yml (legacy symlink → monolith)"
fi

link_tracked_entries ".config/gh-dash" "$HOME/.config/gh-dash"

# Seed the live config.yml with Solarized on first run; subsequent runs
# preserve a prior `theme-set <name>` pick.
if [ ! -f "$HOME/.config/gh-dash/config.yml" ]; then
    cat "$HOME/.config/gh-dash/config-base.yml" \
        "$HOME/.config/gh-dash/theme-colors-solarized.yml" \
        > "$HOME/.config/gh-dash/config.yml"
    echo "✨  $HOME/.config/gh-dash/config.yml (seeded from base + solarized)"
fi

# --- gh extensions (idempotent; needs `gh` from brew, no `gh auth` required)
if ! gh extension list 2>/dev/null | grep -q '^gh dash'; then
  echo "🧩 installing gh dash..."
  gh extension install dlvhdr/gh-dash || \
    echo "⚠️  gh extension install failed (network?) — re-run bootstrap when online"
fi

# --- lnav (TUI log navigator)
# ~/.config/lnav/ is a real dir. formats/installed/ is whole-dir-symlinked to
# the repo. configs/installed/ is mixed-dir: tracked theme variants
# (catppuccin theme-defs + theme-{solarized,mocha}.json selectors) are
# per-file symlinks; the active theme.json is a machine-local symlink. lnav
# writes its built-in samples (configs/default, formats/default), crash
# dumps, staging area, log_metadata.db, view-info-*.json into the real dir.
LNAV_HOME="$HOME/.config/lnav"
LNAV_REPO=".config/lnav"
# 1. Old whole-dir symlink → tear down so we can rebuild as a real dir
if [ -L "$LNAV_HOME" ]; then
  rm "$LNAV_HOME"
  echo "🗑️  $LNAV_HOME (legacy whole-dir symlink)"
fi
# 2. Stale runtime artifacts inside the repo (from pre-migration lnav runs).
#    Only the known set lnav itself emits — never touch installed/.
rm -rf  "$DOTFILES/$LNAV_REPO/configs/default" \
        "$DOTFILES/$LNAV_REPO/formats/default" \
        "$DOTFILES/$LNAV_REPO/crash" \
        "$DOTFILES/$LNAV_REPO/staging"
rm -f   "$DOTFILES/$LNAV_REPO/log_metadata.db" \
        "$DOTFILES/$LNAV_REPO/config.json"
rm -f   "$DOTFILES/$LNAV_REPO"/view-info-*.json
# 3. New shape: real parent dirs; configs/installed is itself a real
#    mixed-dir (per-file symlinks for tracked entries) so a machine-local
#    theme.json symlink can live alongside the tracked theme variants.
#    formats/installed stays whole-dir-symlinked (no machine-local entries).
mkdir -p "$LNAV_HOME/configs"
prepare_real_dir "$LNAV_HOME/configs/installed"
link_tracked_entries "$LNAV_REPO/configs/installed" "$LNAV_HOME/configs/installed"
[ -L "$LNAV_HOME/configs/installed/theme.json" ] \
    || ln -sfn theme-solarized.json "$LNAV_HOME/configs/installed/theme.json"
link "$LNAV_REPO/formats/installed" "$LNAV_HOME/formats/installed"
unset LNAV_HOME LNAV_REPO

# --- sesh: shared config is symlinked; machine-local sessions in sesh.local.toml
link ".config/sesh/sesh.toml" "$HOME/.config/sesh/sesh.toml"
if [ ! -f "$HOME/.config/sesh/sesh.local.toml" ]; then
  cp "$DOTFILES/.config/sesh/sesh.local.toml.template" "$HOME/.config/sesh/sesh.local.toml"
  echo "✨  ~/.config/sesh/sesh.local.toml (edit to add machine-local sessions)"
fi

# --- mise (polyglot runtime version manager)
# Stored as mise.global.toml at repo root (not under .config/mise/) to avoid
# mise auto-discovering it as a local project config when inside the dotfiles dir.
link "mise.global.toml" "$HOME/.config/mise/config.toml"
mise install

# --- uv-managed Python (global default)
# `--default` drops python/python3/python3.13 symlinks into ~/.local/bin
# so bare `python3` resolves to a current interpreter (Apple's 3.9.6 is
# EOL Oct 2025). Idempotent: re-running is a no-op once installed.
# `--preview-features python-install-default` silences uv's "experimental"
# warning on the --default flag (uv 0.11.x). Drop the flag once Astral
# graduates --default out of preview.
uv python install 3.13 --default --preview-features python-install-default

# --- nvim
# ~/.config/nvim/ is a real dir; tracked entries are individually symlinked.
# LazyVim's lazy/, mason/, site/, lazyvim.json stay outside the repo.
prepare_real_dir "$HOME/.config/nvim"
for f in lazy mason site lazyvim.json; do
  rescue_in_repo "$DOTFILES/.config/nvim/$f" "$HOME/.config/nvim/$f"
done
link_tracked_entries ".config/nvim" "$HOME/.config/nvim"

# --- vim
link ".vimrc"          "$HOME/.vimrc"
link ".vim/colors"     "$HOME/.vim/colors"
mkdir -p "$HOME/.vim/undo" "$HOME/.vim/backup" "$HOME/.vim/swap"

# --- starship (prompt; fish opts into transient prompt — see CLAUDE.md)
# Five variant configs tracked; active one symlinked machine-locally.
link ".config/starship-solarized.toml"   "$HOME/.config/starship-solarized.toml"
link ".config/starship-mocha.toml"       "$HOME/.config/starship-mocha.toml"
link ".config/starship-frappe.toml"      "$HOME/.config/starship-frappe.toml"
link ".config/starship-dracula.toml"     "$HOME/.config/starship-dracula.toml"
link ".config/starship-gruvbox.toml"     "$HOME/.config/starship-gruvbox.toml"
link ".config/starship-tokyo-night.toml" "$HOME/.config/starship-tokyo-night.toml"
link ".config/starship-nord.toml"        "$HOME/.config/starship-nord.toml"
link ".config/starship-latte.toml"       "$HOME/.config/starship-latte.toml"
link ".config/starship-rose-pine.toml"      "$HOME/.config/starship-rose-pine.toml"
link ".config/starship-rose-pine-moon.toml" "$HOME/.config/starship-rose-pine-moon.toml"
[ -L "$HOME/.config/starship.toml" ] \
    || ln -sfn starship-solarized.toml "$HOME/.config/starship.toml"

# --- fish (only interactive shell)
# ~/.config/fish/ is a real dir; tracked entries are individually symlinked.
# 15-local.fish + 99-secrets.fish + fish runtime state stay outside the repo.
# completions/ is also a real dir — installers (e.g. OrbStack) and fish's
# own man-page auto-generation drop machine-specific completions there;
# only the tracked entries (s.fish, wt.fish) come from the repo.

# Migration: while ~/.config/fish/completions is still the legacy whole-dir
# symlink into the repo, untracked completions live physically in the repo
# working tree. Stash them to a temp dir, flip the symlink to a real dir,
# move them back. Drops *.barnybug-backup-* (OrbStack installer cruft).
COMPLETIONS_HOME="$HOME/.config/fish/completions"
if [ -L "$COMPLETIONS_HOME" ]; then
  STASH=$(mktemp -d)
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    name="$(basename "$rel")"
    case "$name" in
      *.barnybug-backup-*)
        rm -f "$DOTFILES/$rel"
        echo "🗑️  $rel (installer backup)"
        continue
        ;;
    esac
    mv "$DOTFILES/$rel" "$STASH/$name"
  done < <(git -C "$DOTFILES" ls-files --others --exclude-standard \
                 ".config/fish/completions/")
  rm "$COMPLETIONS_HOME"
  mkdir -p "$COMPLETIONS_HOME"
  for f in "$STASH"/*; do
    [ -e "$f" ] || continue
    mv "$f" "$COMPLETIONS_HOME/$(basename "$f")"
    echo "🚚  $(basename "$f") → $COMPLETIONS_HOME/"
  done
  rmdir "$STASH" 2>/dev/null || true
fi
unset COMPLETIONS_HOME

prepare_real_dir "$HOME/.config/fish"
prepare_real_dir "$HOME/.config/fish/conf.d"
prepare_real_dir "$HOME/.config/fish/completions"
for f in 15-local.fish 99-secrets.fish; do
  rescue_in_repo "$DOTFILES/.config/fish/conf.d/$f" \
                 "$HOME/.config/fish/conf.d/$f"
done
for f in fish_variables fish_history generated_completions; do
  rescue_in_repo "$DOTFILES/.config/fish/$f" "$HOME/.config/fish/$f"
done
link_tracked_entries ".config/fish"             "$HOME/.config/fish"
link_tracked_entries ".config/fish/conf.d"      "$HOME/.config/fish/conf.d"
link_tracked_entries ".config/fish/completions" "$HOME/.config/fish/completions"
seed_local ".config/fish/conf.d/15-local.fish.template" \
           "$HOME/.config/fish/conf.d/15-local.fish"
seed_local ".config/fish/conf.d/99-secrets.fish.template" \
           "$HOME/.config/fish/conf.d/99-secrets.fish"

# --- git (global ignore — paths excluded across every repo on this machine)
link ".gitignore_global" "$HOME/.gitignore_global"

# --- claude
link ".claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# --- bin (user commands on $PATH)
# Symlink each file individually because ~/.local/bin/ typically contains
# other user-installed binaries that shouldn't be displaced by linking the
# whole directory.
# One-time cleanup: bin/dashboard removed in #239; rm the stale symlink
# left behind on already-bootstrapped machines. Idempotent — silent on
# missing file. Safe to leave indefinitely.
rm -f "$HOME/.local/bin/dashboard"
for src in "$DOTFILES"/bin/*; do
  [ -e "$src" ] || continue
  link "bin/$(basename "$src")" "$HOME/.local/bin/$(basename "$src")"
done

# --- TPM (clone if missing; warn but don't abort if offline)
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR/.git" ]; then
  echo "⬇️  cloning TPM..."
  if ! git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR" 2>&1; then
    echo "⚠️  TPM clone failed (offline?) — re-run bootstrap when online"
  fi
else
  echo "✅  $TPM_DIR (TPM present)"
fi

echo
echo "🎯 next steps:"
echo "  🪟 start tmux:               tmux"
echo "  🧩 install plugins:          <prefix> I  (capital I, prefix = C-a)"
echo "  🔍 test session picker:      <prefix> t"
echo "  🐟 set fish as login shell:  see README.md → \"Manual extras\" → 1 (Login shell — fish)"
echo "  🪝 delta + Claude hooks:     see README.md → \"Setup (new machine)\" → Manual extras"

echo "🎉 dotfiles linked — finish with the next steps above"
