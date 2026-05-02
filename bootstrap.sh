#!/usr/bin/env bash
# bootstrap.sh — idempotent dotfiles installer.
# Re-running is safe: every step checks "already done" and skips.
set -euo pipefail

DOTFILES="$PROJECTS_HOME/dotfiles"

# link <source-relative-to-DOTFILES> <target-absolute>
link() {
  local src="$DOTFILES/$1"
  local dst="$2"
  if [ ! -e "$src" ]; then
    echo "missing: $src (skipping)"
    return 0
  fi
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok:     $dst"
    return 0
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="$dst.bak.$(date +%s)"
    echo "BACKUP: $dst -> $backup"
    mv "$dst" "$backup"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  echo "linked: $dst -> $src"
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
  echo "removed: $LNAV_HOME (legacy whole-dir symlink)"
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
  echo "created: ~/.config/sesh/sesh.local.toml (edit to add machine-local sessions)"
fi

# --- nvim
link ".config/nvim"    "$HOME/.config/nvim"

# --- vim
link ".vimrc"          "$HOME/.vimrc"
link ".vim/colors"     "$HOME/.vim/colors"
mkdir -p "$HOME/.vim/undo" "$HOME/.vim/backup" "$HOME/.vim/swap"

# --- zsh
link ".zshrc"     "$HOME/.zshrc"
link ".p10k.zsh"  "$HOME/.p10k.zsh"

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
  echo "cloning TPM..."
  if ! git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR" 2>&1; then
    echo "WARN:   TPM clone failed (offline?) — re-run bootstrap when online"
  fi
else
  echo "ok:     $TPM_DIR (TPM present)"
fi

# --- brew check (don't install — just report)
echo
echo "brew bundle check:"
brew bundle check --file="$DOTFILES/Brewfile" --verbose || \
  echo "-> run: brew bundle --file=$DOTFILES/Brewfile"

echo
echo "next steps:"
echo "  1. start tmux:               tmux"
echo "  2. install plugins:          <prefix> I  (capital I, prefix = C-a)"
echo "  3. test session picker:      <prefix> t"
echo "  4. create machine config:    cp \$DOTFILES/.zshrc.local.template ~/.zshrc.local && \$EDITOR ~/.zshrc.local"
echo "  5. delta + Claude hooks:     see README.md → \"Setup (new machine)\" → Manual extras"
