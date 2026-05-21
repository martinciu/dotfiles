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
