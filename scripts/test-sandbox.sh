#!/opt/homebrew/bin/bash
# test-sandbox.sh — smoke test for the containerized sandbox.
# Lints the wrapper/scripts, builds the image, and asserts runtime isolation.
set -euo pipefail
cd "$(dirname "$0")/.."

pass() { echo "✅ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# 1. Lint.
shellcheck bin/sandbox sandbox/install-linux.sh scripts/test-sandbox.sh \
  || fail "shellcheck"
pass "shellcheck"

# 2. fish parses the completions + guarded env.
fish -n .config/fish/completions/sandbox.fish || fail "completions parse"
fish -n .config/fish/conf.d/00-env.fish || fail "00-env parse"
pass "fish parse"

# Theme flip logic (no docker) — Solarized floor + guarded overlay + delta wiring.
theme_flip_test() {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/.config/lnav/configs"
  cp -R .config/themes "$tmp/.config/themes"
  cp -R .config/glow "$tmp/.config/glow"
  cp -R .config/lnav/configs/installed "$tmp/.config/lnav/configs/installed"
  cp .config/starship-*.toml "$tmp/.config/"

  # Full-coverage theme: every tool overlays off the floor.
  HOME="$tmp" bash sandbox/install-linux.sh theme nord
  [ "$(readlink "$tmp/.config/starship.toml")" = "starship-nord.toml" ] \
    || { echo "❌ nord starship: $(readlink "$tmp/.config/starship.toml")"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/themes/current.tmux")" = "nord.tmux" ] \
    || { echo "❌ nord current.tmux"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/themes/delta-current.gitconfig")" = "delta-nord.gitconfig" ] \
    || { echo "❌ nord delta"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/glow/glamour.json")" = "glamour-nord.json" ] \
    || { echo "❌ nord glow"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/lnav/configs/installed/theme.json")" = "theme-nord.json" ] \
    || { echo "❌ nord lnav"; rm -rf "$tmp"; exit 1; }
  grep -q 'pager = delta' "$tmp/.gitconfig" \
    || { echo "❌ nord gitconfig missing delta"; rm -rf "$tmp"; exit 1; }
  # shellcheck disable=SC2016
  [ "$(HOME="$tmp" fish -c 'echo $BAT_THEME' 2>/dev/null)" = "Nord" ] \
    || { echo "❌ nord BAT_THEME"; rm -rf "$tmp"; exit 1; }

  # Partial-coverage theme (Latte): starship overlays, delta/glow hold the floor.
  HOME="$tmp" bash sandbox/install-linux.sh theme latte
  [ "$(readlink "$tmp/.config/starship.toml")" = "starship-latte.toml" ] \
    || { echo "❌ latte starship overlay"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/glow/glamour.json")" = "glamour-solarized.json" ] \
    || { echo "❌ latte glow floor"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/themes/delta-current.gitconfig")" = "delta-solarized.gitconfig" ] \
    || { echo "❌ latte delta floor"; rm -rf "$tmp"; exit 1; }
  # shellcheck disable=SC2016
  [ "$(HOME="$tmp" fish -c 'echo $BAT_THEME' 2>/dev/null)" = "Catppuccin Latte" ] \
    || { echo "❌ latte BAT_THEME"; rm -rf "$tmp"; exit 1; }

  rm -rf "$tmp"
}
theme_flip_test
pass "theme flip logic (floor + overlay + delta + env)"

command -v docker >/dev/null 2>&1 || { echo "⏭️  docker absent — skipping build/runtime asserts"; exit 0; }

# 3. Build.
local_args=()
[ -n "${GITHUB_TOKEN:-}" ] && local_args=(--secret "id=github_token,env=GITHUB_TOKEN")
docker build -f sandbox/Dockerfile "${local_args[@]}" -t sandbox:test . >/dev/null || fail "build"
pass "image build"

# 4. fish + tools present.
out="$(docker run --rm sandbox:test fish -c 'echo OK; type -q bat; and echo BAT; type -q wt; and echo WT')"
[[ "$out" == *OK* && "$out" == *BAT* && "$out" == *WT* ]] || fail "tools missing: $out"
pass "fish + tools"

# 5. nvim opens headless.
docker run --rm sandbox:test bash -lc '$HOME/.local/bin/mise exec -- nvim --headless +qa' \
  || fail "nvim headless"
pass "nvim"

# 6. Isolation: a default container has NO host bind-mount.
cid="$(docker run -d --rm --cap-drop ALL --security-opt no-new-privileges \
  -v sandbox-selftest:/home/dev sandbox:test)"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker volume rm sandbox-selftest >/dev/null 2>&1 || true' EXIT
binds="$(docker inspect "$cid" --format '{{range .Mounts}}{{.Type}} {{end}}')"
[[ "$binds" != *bind* ]] || fail "unexpected host bind-mount: $binds"
pass "no host bind-mount by default"

echo "✅ all sandbox smoke checks passed"
