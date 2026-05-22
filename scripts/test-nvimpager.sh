#!/opt/homebrew/bin/bash
# Smoke test: nvimpager is installed, its init.lua compiles and executes
# without Lua errors, and the snacks.scroll reuse enables when snacks is
# present and no-ops cleanly when it is absent. Run after editing
# .config/nvimpager/ or the PAGER wiring in .config/fish/conf.d/00-env.fish.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$DOTFILES/.config/nvimpager/init.lua"

if [ ! -f "$INIT" ]; then
  echo "❌ $INIT missing"
  exit 1
fi

if ! command -v nvimpager >/dev/null 2>&1; then
  echo "⏭️  nvimpager not installed — skipping (brew install nvimpager)"
  exit 0
fi

fail=0

# 1. Guard branches: load init.lua headless and assert enable_scroll() is
#    false for an absent path and true for the real snacks path (when present).
lua_script=$(mktemp /tmp/nvimpager-test.XXXXXX.lua)
trap 'rm -f "$lua_script"' EXIT
cat >"$lua_script" <<'LUA'
local M = assert(loadfile(vim.env.NVIMPAGER_INIT))()
assert(M.enable_scroll("/nonexistent/snacks.nvim") == false,
  "absent snacks path must return false")
local real = vim.fn.expand("~/.local/share/nvim/lazy/snacks.nvim")
if (vim.uv or vim.loop).fs_stat(real) then
  assert(M.enable_scroll(real) == true, "present snacks path must return true")
end
io.write("guard-ok\n")
LUA

if ! out=$(NVIMPAGER_INIT="$INIT" nvim --clean -l "$lua_script" 2>&1); then
  echo "❌ nvimpager init.lua guard check failed:"
  echo "$out"
  fail=1
elif ! printf '%s' "$out" | grep -q 'guard-ok'; then
  echo "❌ nvimpager init.lua guard check did not assert cleanly:"
  echo "$out"
  fail=1
fi

# 2. End-to-end cat mode: the real nvimpager binary loads init.lua and echoes
#    piped content (proves init executes under nvimpager itself).
if ! out=$(printf '# hello\n\nworld\n' | nvimpager -c 2>/tmp/nvimpager-cat-err); then
  echo "❌ nvimpager cat-mode exited non-zero:"
  cat /tmp/nvimpager-cat-err
  fail=1
elif ! printf '%s' "$out" | grep -q 'hello'; then
  echo "❌ nvimpager cat-mode did not echo input content"
  fail=1
fi

[ $fail -eq 0 ] && echo "✅ nvimpager smoke passed"
exit $fail
