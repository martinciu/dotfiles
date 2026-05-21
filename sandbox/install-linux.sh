#!/usr/bin/env bash
# install-linux.sh — Linux setup for the dotfiles sandbox. Shared by the
# container image build (per-stage, for layer caching) and OrbStack machine
# provisioning (`all`). Idempotent: re-running is safe.
set -euo pipefail

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
MISE="$HOME/.local/bin/mise"

stage_base() {
  $SUDO apt-get update
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git fish locales build-essential tini less unzip openssh-client
  $SUDO rm -rf /var/lib/apt/lists/*
  # Locales the fish config references (en_US default; pl_PL for LC_TIME).
  $SUDO sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/; s/^# *pl_PL.UTF-8/pl_PL.UTF-8/' /etc/locale.gen
  $SUDO locale-gen
}

stage_mise() {
  if [ ! -x "$MISE" ] && ! command -v mise >/dev/null 2>&1; then
    curl https://mise.run | sh
  fi
  "$MISE" install -y
  "$MISE" reshim
}

stage_nvim() {
  # Build-time plugin bake so nvim opens instantly/offline in every container.
  # theme.lua falls back to solarized when ~/.config/themes/current.tmux is
  # absent (it is, inside the sandbox), so no theme guard is needed.
  "$MISE" exec -- nvim --headless "+Lazy! sync" +qa 2>&1 | tail -n 3 || true
  "$MISE" exec -- nvim --headless "+TSUpdateSync" +qa 2>&1 | tail -n 3 || true
}

stage_config() {
  # Seed EMPTY machine-local fish files from templates (never real secrets).
  for f in 15-local 99-secrets; do
    tmpl="$HOME/.config/fish/conf.d/$f.fish.template"
    real="$HOME/.config/fish/conf.d/$f.fish"
    if [ -f "$tmpl" ] && [ ! -f "$real" ]; then
      cp "$tmpl" "$real"
    fi
  done
  # Make fish the login shell for this user.
  if command -v fish >/dev/null 2>&1; then
    fsh="$(command -v fish)"
    grep -qx "$fsh" /etc/shells || echo "$fsh" | $SUDO tee -a /etc/shells >/dev/null
    $SUDO chsh -s "$fsh" "$(id -un)" || true
  fi
}

case "${1:-all}" in
  base) stage_base ;;
  mise) stage_mise ;;
  nvim) stage_nvim ;;
  config) stage_config ;;
  all) stage_base; stage_mise; stage_nvim; stage_config ;;
  *) echo "usage: install-linux.sh [base|mise|nvim|config|all]" >&2; exit 1 ;;
esac
