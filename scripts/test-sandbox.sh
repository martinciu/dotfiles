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
  # fish 4.x universals are written to ~/.config/fish/fish_variables; reading
  # via `fish -c` hits the running daemon instead, so grep the file directly.
  grep -q 'BAT_THEME:Nord' "$tmp/.config/fish/fish_variables" 2>/dev/null \
    || { echo "❌ nord BAT_THEME"; rm -rf "$tmp"; exit 1; }

  # Partial-coverage theme (Latte): starship overlays, delta/glow hold the floor.
  HOME="$tmp" bash sandbox/install-linux.sh theme latte
  [ "$(readlink "$tmp/.config/starship.toml")" = "starship-latte.toml" ] \
    || { echo "❌ latte starship overlay"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/glow/glamour.json")" = "glamour-solarized.json" ] \
    || { echo "❌ latte glow floor"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/themes/delta-current.gitconfig")" = "delta-solarized.gitconfig" ] \
    || { echo "❌ latte delta floor"; rm -rf "$tmp"; exit 1; }
  # Latte's bat name has a space; fish 4.x encodes spaces as \x20 in the file.
  grep -q 'BAT_THEME:Catppuccin' "$tmp/.config/fish/fish_variables" 2>/dev/null \
    || { echo "❌ latte BAT_THEME"; rm -rf "$tmp"; exit 1; }

  rm -rf "$tmp"
}
theme_flip_test
pass "theme flip logic (floor + overlay + delta + env)"

command -v docker >/dev/null 2>&1 || { echo "⏭️  docker absent — skipping build/runtime asserts"; exit 0; }

# 3. Build via the wrapper so the image carries the sandbox.srchash label —
# the reup/run wrapper tests below then reuse it without ensure_image rebuilding.
SANDBOX_IMAGE=sandbox:test bin/sandbox build >/dev/null || fail "build"
pass "image build"

# 4. fish + tools present.
out="$(docker run --rm sandbox:test fish -c 'echo OK; type -q bat; and echo BAT; type -q wt; and echo WT')"
[[ "$out" == *OK* && "$out" == *BAT* && "$out" == *WT* ]] || fail "tools missing: $out"
pass "fish + tools"

# 5. nvim opens headless.
docker run --rm sandbox:test bash -lc '$HOME/.local/bin/mise exec -- nvim --headless +qa' \
  || fail "nvim headless"
pass "nvim"

# Theme apply in the built image: floor default, full-coverage overlay, and
# Latte partial-coverage degradation.
out="$(docker run --rm sandbox:test bash -lc 'readlink ~/.config/starship.toml')"
[[ "$out" == "starship-solarized.toml" ]] || fail "theme floor default: $out"
pass "theme floor default"

out="$(docker run --rm sandbox:test bash -lc '
  bash ~/.sandbox/install-linux.sh theme nord >/dev/null 2>&1
  echo "starship=$(readlink ~/.config/starship.toml)"
  echo "bat=$(fish -c "echo \$BAT_THEME" 2>/dev/null)"
  echo "git=$(grep -c "pager = delta" ~/.gitconfig)"')"
[[ "$out" == *"starship=starship-nord.toml"* ]] || fail "theme nord starship: $out"
[[ "$out" == *"bat=Nord"* ]] || fail "theme nord bat: $out"
[[ "$out" == *"git=1"* ]] || fail "theme nord delta gitconfig: $out"
pass "theme apply (nord)"

out="$(docker run --rm sandbox:test bash -lc '
  bash ~/.sandbox/install-linux.sh theme latte >/dev/null 2>&1
  echo "starship=$(readlink ~/.config/starship.toml)"
  echo "glow=$(readlink ~/.config/glow/glamour.json)"')"
[[ "$out" == *"starship=starship-latte.toml"* ]] || fail "theme latte overlay: $out"
[[ "$out" == *"glow=glamour-solarized.json"* ]] || fail "theme latte glow floor: $out"
pass "theme degrade (latte)"

# 6. Isolation: a default container has NO host bind-mount.
cid="$(docker run -d --rm --cap-drop ALL --security-opt no-new-privileges \
  -v sandbox-selftest:/home/dev sandbox:test)"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true; docker volume rm sandbox-selftest >/dev/null 2>&1 || true' EXIT
binds="$(docker inspect "$cid" --format '{{range .Mounts}}{{.Type}} {{end}}')"
[[ "$binds" != *bind* ]] || fail "unexpected host bind-mount: $binds"
pass "no host bind-mount by default"

# 7. reup: recreate the container with new flags, keeping the /home/dev volume.
rname="reuptest"; rcont="sandbox-$rname"; rport=58080
# Combined cleanup: also clears the step-6 isolation resources ($cid, sandbox-selftest).
trap 'docker rm -f "$cid" "$rcont" >/dev/null 2>&1 || true; docker volume rm sandbox-selftest "$rcont" >/dev/null 2>&1 || true' EXIT
docker rm -f "$rcont" >/dev/null 2>&1 || true
docker volume rm "$rcont" >/dev/null 2>&1 || true
docker run -d --name "$rcont" --label sandbox=1 -v "${rcont}:/home/dev" sandbox:test >/dev/null
docker exec "$rcont" sh -c 'echo survived > /home/dev/sentinel'
SANDBOX_IMAGE=sandbox:test bin/sandbox reup "$rname" -p "$rport" true >/dev/null 2>&1 || true
got="$(docker exec "$rcont" cat /home/dev/sentinel 2>/dev/null || true)"
[[ "$got" == survived ]] || fail "reup lost /home/dev state: '$got'"
pass "reup keeps volume state"
binds="$(docker inspect "$rcont" --format '{{json .HostConfig.PortBindings}}' 2>/dev/null || true)"
[[ "$binds" == *127.0.0.1* && "$binds" == *"$rport"* ]] || fail "reup did not publish port: $binds"
pass "reup applies new -p flag"

# 8. reup on a nonexistent sandbox errors clearly with a non-zero exit.
rc=0; out="$(bin/sandbox reup "nope-$$" 2>&1)" || rc=$?
[[ "$rc" -ne 0 && "$out" == *"no such sandbox"* ]] || fail "reup nonexistent: rc=$rc out=$out"
pass "reup nonexistent errors"

# 9. Bare `sandbox <name>` warns when creation-time flags hit an existing container.
out="$(SANDBOX_IMAGE=sandbox:test bin/sandbox "$rname" -p "$rport" true 2>&1 || true)"
[[ "$out" == *"flags ignored"* && "$out" == *"sandbox reup"* ]] || fail "missing ignored-flags warning: $out"
pass "ignored-flags warning"

# 10. help is a real subcommand: prints usage, exits 0, creates nothing.
docker rm -f sandbox-help >/dev/null 2>&1 || true   # remove any leftover from a prior run
rc=0; out="$(SANDBOX_IMAGE=sandbox:test bin/sandbox help 2>&1)" || rc=$?
[[ "$rc" -eq 0 && "$out" == *Usage* ]] || fail "help: rc=$rc out=$out"
docker container inspect sandbox-help >/dev/null 2>&1 && fail "help created a container"
pass "help prints usage, creates nothing"

# 11. A bogus subcommand errors non-zero and creates nothing.
docker rm -f sandbox-lst >/dev/null 2>&1 || true   # remove any leftover from a prior run
rc=0; out="$(SANDBOX_IMAGE=sandbox:test bin/sandbox lst 2>&1)" || rc=$?
[[ "$rc" -ne 0 && "$out" == *"no such sandbox"* ]] || fail "bogus token: rc=$rc out=$out"
docker container inspect sandbox-lst >/dev/null 2>&1 && fail "bogus token created a container"
pass "bogus subcommand errors, creates nothing"

# 12. create provisions; bare attach re-enters; bare on an absent name errors + creates nothing.
ctname="createtest"; ctcont="sandbox-$ctname"
# Extend cleanup to also clear the create-test container + volume (keeps step 6/7 resources too).
trap 'docker rm -f "$cid" "$rcont" "$ctcont" >/dev/null 2>&1 || true; docker volume rm sandbox-selftest "$rcont" "$ctcont" >/dev/null 2>&1 || true' EXIT
docker rm -f "$ctcont" >/dev/null 2>&1 || true
docker volume rm "$ctcont" >/dev/null 2>&1 || true
SANDBOX_IMAGE=sandbox:test bin/sandbox create "$ctname" true >/dev/null 2>&1 || true
docker container inspect "$ctcont" >/dev/null 2>&1 || fail "create did not provision $ctcont"
pass "create provisions a sandbox"
out="$(SANDBOX_IMAGE=sandbox:test bin/sandbox "$ctname" true 2>&1 || true)"
[[ "$out" != *"no such sandbox"* ]] || fail "bare attach errored on existing: $out"
pass "bare attach re-enters existing sandbox"
rc=0; out="$(SANDBOX_IMAGE=sandbox:test bin/sandbox "nope-$$" 2>&1)" || rc=$?
[[ "$rc" -ne 0 && "$out" == *"no such sandbox"* ]] || fail "bare absent: rc=$rc out=$out"
docker container inspect "sandbox-nope-$$" >/dev/null 2>&1 && fail "bare absent created a container"
pass "bare attach on absent errors, creates nothing"

echo "✅ all sandbox smoke checks passed"
