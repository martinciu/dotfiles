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

# --- ghostty (already done; idempotent re-link)
link ".config/ghostty" "$HOME/.config/ghostty"

# --- tmux
link ".config/tmux"    "$HOME/.config/tmux"

# --- ccstatusline
link ".config/ccstatusline" "$HOME/.config/ccstatusline"

# --- worktrunk
link ".config/worktrunk" "$HOME/.config/worktrunk"

# --- glow
link ".config/glow"    "$HOME/.config/glow"

# --- tailspin (tspin) — Solarized theme.toml
link ".config/tailspin" "$HOME/.config/tailspin"

# --- btop
link ".config/btop"    "$HOME/.config/btop"

# --- procs (modern ps; Solarized config + procs-heavy.toml for `psh`)
link ".config/procs"   "$HOME/.config/procs"

# --- xh (modern HTTP client; Solarized via default_options)
link ".config/xh"      "$HOME/.config/xh"

# --- tealdeer (modern man supplement; Solarized [style] + auto-update)
link ".config/tealdeer" "$HOME/.config/tealdeer"

# --- lnav (TUI log navigator; only installed/ subdirs are symlinked from repo)
# lnav writes its built-in samples (configs/default, formats/default), crash
# dumps, staging area, log_metadata.db, view-info-*.json, and :config-written
# config.json into the real ~/.config/lnav/ — outside the repo. We only own
# the two installed/ subdirs.
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
# 3. New shape: real parent dirs + dir-level symlinks for installed/
mkdir -p "$LNAV_HOME/configs" "$LNAV_HOME/formats"
link "$LNAV_REPO/configs/installed" "$LNAV_HOME/configs/installed"
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

# --- nvim
link ".config/nvim"    "$HOME/.config/nvim"

# --- vim
link ".vimrc"          "$HOME/.vimrc"
link ".vim/colors"     "$HOME/.vim/colors"
mkdir -p "$HOME/.vim/undo" "$HOME/.vim/backup" "$HOME/.vim/swap"

# --- zsh (fallback — see REMOVAL.md)
link ".config/zsh" "$HOME/.config/zsh"
link ".zshrc"      "$HOME/.zshrc"
link ".zprofile"   "$HOME/.zprofile"
link ".config/starship.toml" "$HOME/.config/starship.toml"

# --- fish (primary)
# ~/.config/fish/ is a real dir; tracked entries are individually symlinked.
# 15-local.fish + 99-secrets.fish + fish runtime state stay outside the repo.
prepare_real_dir "$HOME/.config/fish"
prepare_real_dir "$HOME/.config/fish/conf.d"
for f in 15-local.fish 99-secrets.fish; do
  rescue_in_repo "$DOTFILES/.config/fish/conf.d/$f" \
                 "$HOME/.config/fish/conf.d/$f"
done
for f in fish_variables fish_history generated_completions; do
  rescue_in_repo "$DOTFILES/.config/fish/$f" "$HOME/.config/fish/$f"
done
link_tracked_entries ".config/fish"        "$HOME/.config/fish"
link_tracked_entries ".config/fish/conf.d" "$HOME/.config/fish/conf.d"
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
echo "  🛟 zsh fallback machine cfg: see README.md → \"Manual extras\" → 5 (Fallback shell — zsh)"
echo "  🪝 delta + Claude hooks:     see README.md → \"Setup (new machine)\" → Manual extras"

echo "🎉 dotfiles linked — finish with the next steps above"
