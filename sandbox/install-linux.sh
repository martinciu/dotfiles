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
    ca-certificates curl git fish procps locales build-essential tini less unzip openssh-client
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

stage_theme() {
  # Bash port of theme-set.fish, scoped to the sandbox toolset (no tmux,
  # ghostty, gh-dash, or fonts). Solarized floor + existence-guarded overlay,
  # so partial-coverage themes (Latte) degrade to the floor for the tools they
  # don't ship. Invoked at build (floor) and at runtime (host theme).
  local name="${2:-solarized}"
  local cfg="$HOME/.config"
  local bat vivid
  case "$name" in
    mocha)          bat="Catppuccin Mocha";  vivid="catppuccin-mocha" ;;
    frappe)         bat="Catppuccin Frappé"; vivid="catppuccin-frappe" ;;
    dracula)        bat="Dracula";           vivid="dracula" ;;
    gruvbox)        bat="gruvbox-dark";      vivid="gruvbox-dark" ;;
    tokyo-night)    bat="Catppuccin Mocha";  vivid="tokyonight-storm" ;;
    nord)           bat="Nord";              vivid="nord" ;;
    latte)          bat="Catppuccin Latte";  vivid="catppuccin-latte" ;;
    rose-pine)      bat="Catppuccin Mocha";  vivid="rose-pine" ;;
    rose-pine-moon) bat="Catppuccin Mocha";  vivid="rose-pine-moon" ;;
    *)              name="solarized"; bat="Solarized (dark)"; vivid="solarized-dark" ;;
  esac

  # Solarized floor (relative targets resolve within each link's dir).
  ln -sfn solarized.tmux            "$cfg/themes/current.tmux"
  ln -sfn delta-solarized.gitconfig "$cfg/themes/delta-current.gitconfig"
  ln -sfn starship-solarized.toml   "$cfg/starship.toml"
  ln -sfn glamour-solarized.json    "$cfg/glow/glamour.json"
  ln -sfn theme-solarized.json      "$cfg/lnav/configs/installed/theme.json"

  # Active theme overlay where its assets exist (Latte degrades to the floor).
  [ -f "$cfg/themes/$name.tmux" ] \
    && ln -sfn "$name.tmux" "$cfg/themes/current.tmux"
  [ -f "$cfg/themes/delta-$name.gitconfig" ] \
    && ln -sfn "delta-$name.gitconfig" "$cfg/themes/delta-current.gitconfig"
  [ -f "$cfg/starship-$name.toml" ] \
    && ln -sfn "starship-$name.toml" "$cfg/starship.toml"
  [ -f "$cfg/glow/glamour-$name.json" ] \
    && ln -sfn "glamour-$name.json" "$cfg/glow/glamour.json"
  [ -f "$cfg/lnav/configs/installed/theme-$name.json" ] \
    && ln -sfn "theme-$name.json" "$cfg/lnav/configs/installed/theme.json"

  # delta git wiring — write a minimal ~/.gitconfig only if absent (the sandbox
  # ships the delta binary but never wires it as git's pager; mirrors README
  # step 3). A missing include target is silently ignored by git, so the Latte
  # floor (delta-solarized.gitconfig) is always present and safe.
  if [ ! -f "$HOME/.gitconfig" ]; then
    cat > "$HOME/.gitconfig" <<'GITEOF'
[core]
	pager = delta
[interactive]
	diffFilter = delta --color-only
[delta]
	navigate = true
	line-numbers = true
[include]
	path = ~/.config/themes/delta-current.gitconfig
GITEOF
  fi

  # bat/vivid as fish universal vars (loaded before conf.d, so 10-colors.fish's
  # `vivid generate $VIVID_THEME` sees them). Mirrors theme-set.fish on the host.
  # Last statement in the function, and `|| true`, so a benign last-overlay miss
  # or a missing fish never makes the stage exit non-zero.
  if command -v fish >/dev/null 2>&1; then
    fish -c "set -Ux BAT_THEME '$bat'; set -Ux VIVID_THEME '$vivid'" 2>/dev/null || true
  fi
}

case "${1:-all}" in
  base) stage_base ;;
  mise) stage_mise ;;
  nvim) stage_nvim ;;
  config) stage_config ;;
  theme) stage_theme "$@" ;;
  all) stage_base; stage_mise; stage_nvim; stage_config; stage_theme ;;
  *) echo "usage: install-linux.sh [base|mise|nvim|config|theme|all]" >&2; exit 1 ;;
esac
