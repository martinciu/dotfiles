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

echo "✅ all sandbox smoke checks passed"
