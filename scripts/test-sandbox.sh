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

# Guard A — Mac-unchanged: the shared per-theme tomls must NOT carry git or
# container modules. Those live only in the generated sandbox config; a leak
# here would change the Mac prompt.
for f in .config/starship-*.toml; do
  # shellcheck disable=SC2016
  ! grep -qE '^\[(container|git_branch|git_status)\]|\$container|\$git_branch' "$f" \
    || fail "Mac leak: $f carries a sandbox-only module"
done
pass "Mac starship tomls carry no git/container modules"

# Guard B — transform-target drift: generate_starship's sed targets exact lines
# shared by all 10 tomls. If a theme's format/right_format drifts, injection
# would silently no-op. Fail loudly instead.
for f in .config/starship-*.toml; do
  # shellcheck disable=SC2016
  grep -q '^format = """\$directory' "$f" \
    || fail "transform drift: $f format line changed"
  # shellcheck disable=SC2016
  grep -q '^right_format = "\$status\$cmd_duration"$' "$f" \
    || fail "transform drift: $f right_format line changed"
done
pass "all starship tomls share the transform-target lines"

# Theme flip logic (no docker) — Solarized floor + guarded overlay + delta wiring.
theme_flip_test() {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/.config/lnav/configs"
  cp -R .config/themes "$tmp/.config/themes"
  cp -R .config/glow "$tmp/.config/glow"
  cp -R .config/lnav/configs/installed "$tmp/.config/lnav/configs/installed"
  cp -R .config/eza "$tmp/.config/eza"
  cp .config/starship-*.toml "$tmp/.config/"
  cp -R .config/git "$tmp/.config/git"

  # Full-coverage theme: every tool overlays off the floor.
  HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" bash sandbox/install-linux.sh theme nord
  ! [ -L "$tmp/.config/starship.toml" ] \
    || { echo "❌ nord starship should be a generated real file, not a symlink"; rm -rf "$tmp"; exit 1; }
  grep -q '^palette = "nord"' "$tmp/.config/starship.toml" \
    || { echo "❌ nord starship palette"; rm -rf "$tmp"; exit 1; }
  # shellcheck disable=SC2016
  grep -q '^format = """\$container\$directory' "$tmp/.config/starship.toml" \
    || { echo "❌ nord starship: \$container not in format"; rm -rf "$tmp"; exit 1; }
  # shellcheck disable=SC2016
  grep -q '^right_format = "\$git_branch\$git_status\$status\$cmd_duration"$' "$tmp/.config/starship.toml" \
    || { echo "❌ nord starship right_format"; rm -rf "$tmp"; exit 1; }
  for blk in container git_branch git_status; do
    grep -q "^\[$blk\]" "$tmp/.config/starship.toml" \
      || { echo "❌ nord starship missing [$blk]"; rm -rf "$tmp"; exit 1; }
  done
  # The penguin (U+F17C, UTF-8 EF 85 BC) must survive into [container].symbol.
  # printf'd bytes keep this source ASCII-only — a raw glyph here risks the same
  # silent stripping the generated symbol once suffered.
  grep -qF "symbol = \"$(printf '\357\205\274')\"" "$tmp/.config/starship.toml" \
    || { echo "❌ nord starship missing penguin glyph (U+F17C) in [container].symbol"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/themes/current.tmux")" = "nord.tmux" ] \
    || { echo "❌ nord current.tmux"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/themes/delta-current.gitconfig")" = "delta-nord.gitconfig" ] \
    || { echo "❌ nord delta"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/glow/glamour.json")" = "glamour-nord.json" ] \
    || { echo "❌ nord glow"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/lnav/configs/installed/theme.json")" = "theme-nord.json" ] \
    || { echo "❌ nord lnav"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/eza/theme.yml")" = "eza-nord.yml" ] \
    || { echo "❌ nord eza"; rm -rf "$tmp"; exit 1; }
  grep -q 'pager = delta' "$tmp/.gitconfig" \
    || { echo "❌ nord gitconfig missing delta"; rm -rf "$tmp"; exit 1; }
  grep -q 'path = ~/.config/git/aliases.gitconfig' "$tmp/.gitconfig" \
    || { echo "❌ nord gitconfig missing shared aliases include"; rm -rf "$tmp"; exit 1; }
  [ "$(HOME="$tmp" git -C "$tmp" config --get alias.lo)" = "log --oneline" ] \
    || { echo "❌ nord git alias 'lo' not resolved via include"; rm -rf "$tmp"; exit 1; }
  # fish 4.x universals are written to ~/.config/fish/fish_variables; reading
  # via `fish -c` hits the running daemon instead, so grep the file directly.
  grep -q 'BAT_THEME:Nord' "$tmp/.config/fish/fish_variables" 2>/dev/null \
    || { echo "❌ nord BAT_THEME"; rm -rf "$tmp"; exit 1; }

  # Partial-coverage theme (Latte): starship overlays, delta/glow hold the floor.
  HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" bash sandbox/install-linux.sh theme latte
  grep -q '^palette = "catppuccin_latte"' "$tmp/.config/starship.toml" \
    || { echo "❌ latte starship palette"; rm -rf "$tmp"; exit 1; }
  grep -q '^\[git_branch\]' "$tmp/.config/starship.toml" \
    || { echo "❌ latte starship git_branch"; rm -rf "$tmp"; exit 1; }
  [ "$(readlink "$tmp/.config/glow/glamour.json")" = "glamour-solarized.json" ] \
    || { echo "❌ latte glow floor"; rm -rf "$tmp"; exit 1; }
  # eza ships a latte variant → overlays (does NOT hold the solarized floor, unlike glow/delta).
  [ "$(readlink "$tmp/.config/eza/theme.yml")" = "eza-latte.yml" ] \
    || { echo "❌ latte eza overlay"; rm -rf "$tmp"; exit 1; }
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

# 5b. nvimpager: on PATH, $PAGER resolves to it, init.lua present, cat-mode
# echoes piped content, and cat-mode emits the active theme's 24-bit palette
# (38;2;) — the color proxy proves nvimpager's init.lua reached the baked nvim
# lazy dir (snacks/theme reuse, the headline risk of this change). Run via fish
# so mise is active (nvim on PATH) and COLORTERM=truecolor is backfilled; the
# floor (solarized) theme is already applied from the build.
out="$(docker run --rm sandbox:test fish -c '
  type -q nvimpager; and echo ONPATH
  test "$PAGER" = nvimpager; and echo PAGER
  test -f ~/.config/nvimpager/init.lua; and echo INIT
  printf "# hello\n" | nvimpager -c | string match -q "*hello*"; and echo CAT
  printf "local x = 1\n" | nvimpager -c | string match -q "*38;2;*"; and echo COLOR')"
for tok in ONPATH PAGER INIT CAT COLOR; do
  [[ "$out" == *"$tok"* ]] || fail "nvimpager: missing $tok (got: $out)"
done
pass "nvimpager (on PATH, \$PAGER, init.lua, cat-mode, color proxy)"

# Theme apply in the built image: floor default, full-coverage overlay, and
# Latte partial-coverage degradation.
out="$(docker run --rm sandbox:test bash -lc 'cat ~/.config/starship.toml')"
[[ "$out" == *'palette = "solarized_dark"'* ]] || fail "theme floor palette: $out"
[[ "$out" == *'[container]'* ]] || fail "theme floor missing [container]"
[[ "$out" == *'[git_branch]'* ]] || fail "theme floor missing [git_branch]"
# Penguin (U+F17C, UTF-8 EF 85 BC) must reach the in-image generated symbol —
# module-name checks above pass even when the glyph is stripped, so assert the byte.
[[ "$out" == *"symbol = \"$(printf '\357\205\274')\""* ]] || fail "theme floor missing penguin glyph (U+F17C)"
pass "theme floor default (generated)"

# git aliases: the shared aliases.gitconfig is baked (Dockerfile COPY + .dockerignore
# allowlist) and included by the generated ~/.gitconfig, so `git lo` resolves. The only
# tier that proves the COPY + allowlist worked (the no-docker check cannot).
out="$(docker run --rm sandbox:test bash -lc 'git config --get alias.lo')"
[[ "$out" == "log --oneline" ]] || fail "git lo alias not resolved in image: $out"
pass "git lo alias (shared aliases.gitconfig baked + included)"

out="$(docker run --rm sandbox:test bash -lc '
  bash ~/.sandbox/install-linux.sh theme nord >/dev/null 2>&1
  echo "palette=$(grep -m1 "^palette = " ~/.config/starship.toml)"
  echo "gitbranch=$(grep -c "^\[git_branch\]" ~/.config/starship.toml)"
  echo "bat=$(fish -c "echo \$BAT_THEME" 2>/dev/null)"
  echo "git=$(grep -c "pager = delta" ~/.gitconfig)"')"
[[ "$out" == *'palette = "nord"'* ]] || fail "theme nord starship palette: $out"
[[ "$out" == *"gitbranch=1"* ]] || fail "theme nord starship git_branch: $out"
[[ "$out" == *"bat=Nord"* ]] || fail "theme nord bat: $out"
[[ "$out" == *"git=1"* ]] || fail "theme nord delta gitconfig: $out"
pass "theme apply (nord, generated)"

out="$(docker run --rm sandbox:test bash -lc '
  bash ~/.sandbox/install-linux.sh theme latte >/dev/null 2>&1
  echo "palette=$(grep -m1 "^palette = " ~/.config/starship.toml)"
  echo "glow=$(readlink ~/.config/glow/glamour.json)"')"
[[ "$out" == *'palette = "catppuccin_latte"'* ]] || fail "theme latte starship palette: $out"
[[ "$out" == *"glow=glamour-solarized.json"* ]] || fail "theme latte glow floor: $out"
pass "theme degrade (latte, generated)"

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

# 7b. reup with two -p flags (one bare, one remap) publishes BOTH on 127.0.0.1.
rport2_bare=58081; rport2_host=58082; rport2_ctn=82
SANDBOX_IMAGE=sandbox:test bin/sandbox reup "$rname" -p "$rport2_bare" -p "${rport2_host}:${rport2_ctn}" true >/dev/null 2>&1 || true
binds="$(docker inspect "$rcont" --format '{{json .HostConfig.PortBindings}}' 2>/dev/null || true)"
[[ "$binds" == *"\"${rport2_bare}/tcp\""* && "$binds" == *"\"HostPort\":\"${rport2_bare}\""* ]] \
  || fail "reup multi-port: bare ${rport2_bare} not published: $binds"
[[ "$binds" == *"\"${rport2_ctn}/tcp\""* && "$binds" == *"\"HostPort\":\"${rport2_host}\""* ]] \
  || fail "reup multi-port: remap ${rport2_host}:${rport2_ctn} not published: $binds"
[[ "$binds" == *"\"HostIp\":\"127.0.0.1\""* ]] || fail "reup multi-port: not 127.0.0.1-bound: $binds"
pass "reup applies multiple -p flags (bare + remap)"

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
