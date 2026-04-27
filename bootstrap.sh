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

# --- vim
link ".vimrc"          "$HOME/.vimrc"
link ".vim/colors"     "$HOME/.vim/colors"
mkdir -p "$HOME/.vim/undo" "$HOME/.vim/backup" "$HOME/.vim/swap"

# --- zsh
link ".zshrc"     "$HOME/.zshrc"
link ".p10k.zsh"  "$HOME/.p10k.zsh"

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
echo "  3. test sesh popup:          <prefix> T"
echo "  4. create machine config:    cp \$DOTFILES/.zshrc.local.template ~/.zshrc.local && \$EDITOR ~/.zshrc.local"
