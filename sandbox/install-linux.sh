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

stage_nvimpager() {
  # nvimpager isn't a mise/aqua tool and ships no prebuilt binaries — it's a
  # bash script + lua runtime installed via the upstream makefile. Clone the
  # default branch (tracks latest, matching mise.toml's "latest everywhere"),
  # then `make install-no-man` (skips the scdoc man-page dep) into
  # PREFIX=$HOME/.local so the binary lands on PATH (fish_add_path in
  # 00-env.fish) without sudo. Needs only git + make (base stage) + network;
  # nvim is NOT required at build time (`nvimpager -v` doesn't invoke nvim).
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 https://github.com/lucc/nvimpager "$tmp/nvimpager"
  make -C "$tmp/nvimpager" install-no-man PREFIX="$HOME/.local"
  rm -rf "$tmp"
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

# Generate (not symlink) the sandbox starship config from the active theme.
# The Mac prompt deliberately omits git and any container glyph; those additions
# live ONLY here, injected into a copy of the read-only starship-<name>.toml, so
# the shared per-theme tomls (used directly by the Mac) never gain them. This is
# the starship analog of the gh-dash generate-by-concatenation pattern. Portable
# across BSD sed (macOS smoke test) and GNU sed (container).
generate_starship() {
  local cfg="$1" name="$2"
  local src="$cfg/starship-$name.toml"
  [ -f "$src" ] || src="$cfg/starship-solarized.toml"
  local tmp; tmp="$(mktemp)"
  # Prepend $container to the directory line; fold git into right_format.
  # SC2016: single-quote guards are intentional — these are starship token
  # references, not shell variables; we don't want expansion.
  # shellcheck disable=SC2016
  sed -e 's/^format = """\$directory/format = """$container$directory/' \
      -e 's/^right_format = "\$status\$cmd_duration"$/right_format = "$git_branch$git_status$status$cmd_duration"/' \
      "$src" > "$tmp"
  # Sandbox-only modules. [container] self-gates on /.dockerenv (empty on Mac);
  # it reuses the directory chip's palette keys (fg:base3 bg:pastel_rose, defined
  # in every theme) so the penguin sits *inside* the flush-left prompt chip rather
  # than floating on the terminal's default bg. git_branch/git_status use ANSI
  # color names, which resolve to each theme's palette key when defined and fall
  # back to ANSI otherwise — auto-adapting across themes, no per-theme authoring.
  cat >> "$tmp" <<'STARSHIP_EOF'

[container]
format = "[ $symbol]($style)"
symbol = ""
style  = "fg:base3 bg:pastel_rose"

[git_branch]
format = "[$symbol$branch]($style) "
style  = "bold purple"

[git_status]
style = "bold red"
STARSHIP_EOF
  # Atomic replace. Never `>` directly onto starship.toml: at build time / on a
  # re-applied volume it may still be a symlink to the pristine in-image source,
  # and `>` would follow it and corrupt that source.
  mv -f "$tmp" "$cfg/starship.toml"
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
  ln -sfn glamour-solarized.json    "$cfg/glow/glamour.json"
  ln -sfn theme-solarized.json      "$cfg/lnav/configs/installed/theme.json"
  ln -sfn eza-solarized.yml         "$cfg/eza/theme.yml"
  ln -sfn config-solarized.toml     "$cfg/tealdeer/config.toml"

  # Active theme overlay where its assets exist (Latte degrades to the floor).
  [ -f "$cfg/themes/$name.tmux" ] \
    && ln -sfn "$name.tmux" "$cfg/themes/current.tmux"
  [ -f "$cfg/themes/delta-$name.gitconfig" ] \
    && ln -sfn "delta-$name.gitconfig" "$cfg/themes/delta-current.gitconfig"
  generate_starship "$cfg" "$name"
  [ -f "$cfg/glow/glamour-$name.json" ] \
    && ln -sfn "glamour-$name.json" "$cfg/glow/glamour.json"
  [ -f "$cfg/lnav/configs/installed/theme-$name.json" ] \
    && ln -sfn "theme-$name.json" "$cfg/lnav/configs/installed/theme.json"
  [ -f "$cfg/eza/eza-$name.yml" ] \
    && ln -sfn "eza-$name.yml" "$cfg/eza/theme.yml"
  [ -f "$cfg/tealdeer/config-$name.toml" ] \
    && ln -sfn "config-$name.toml" "$cfg/tealdeer/config.toml"

  # lazygit: generated real config.yml (cat base + theme-colors), same contract
  # as gh-dash on the host. lazygit is in the sandbox toolset (mise.toml), so it
  # follows the active theme inside the container. Existence-guarded; the floor
  # (solarized) always ships a theme-colors file so config.yml is never empty.
  if [ -f "$cfg/lazygit/theme-colors-$name.yml" ]; then
    cat "$cfg/lazygit/config-base.yml" \
        "$cfg/lazygit/theme-colors-$name.yml" \
        > "$cfg/lazygit/config.yml"
  elif [ -f "$cfg/lazygit/theme-colors-solarized.yml" ]; then
    cat "$cfg/lazygit/config-base.yml" \
        "$cfg/lazygit/theme-colors-solarized.yml" \
        > "$cfg/lazygit/config.yml"
  fi

  # git wiring — write a minimal ~/.gitconfig only if absent (the sandbox ships
  # the delta binary but never wires it as git's pager; mirrors README step 3).
  # It includes both the theme-dependent delta config and the theme-independent
  # shared aliases (git lo). A missing include target is silently ignored by git,
  # so the Latte floor (delta-solarized.gitconfig) is always present and safe.
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
	path = ~/.config/git/aliases.gitconfig
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
  nvimpager) stage_nvimpager ;;
  nvim) stage_nvim ;;
  config) stage_config ;;
  theme) stage_theme "$@" ;;
  all) stage_base; stage_mise; stage_nvimpager; stage_nvim; stage_config; stage_theme ;;
  *) echo "usage: install-linux.sh [base|mise|nvimpager|nvim|config|theme|all]" >&2; exit 1 ;;
esac
