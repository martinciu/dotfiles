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
-- apply_theme: empty/absent lazy dir returns false without touching colorscheme.
assert(M.apply_theme("/nonexistent/lazy") == false,
  "absent lazy dir must return false")
-- present lazy dir: a colorscheme is applied and recorded in vim.g.colors_name.
local lazy = vim.fn.expand("~/.local/share/nvim/lazy")
if #vim.fn.glob(lazy .. "/*", false, true) > 0 then
  assert(M.apply_theme() == true, "present lazy dir must apply a colorscheme")
  assert(vim.g.colors_name ~= nil, "colors_name must be set after apply_theme")
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

# 3. Cat-mode color: with a theme applied, output carries the colorscheme's
#    24-bit palette (Normal fg as a truecolor SGR `38;2;`). Gated on lazy
#    plugins being installed — a fresh machine before nvim's first launch has
#    none, so the pager correctly stays on terminal default colors.
#    nvimpager reads its config from $XDG_CONFIG_HOME/nvimpager/init.lua; point
#    that at the repo's $INIT so this exercises the file under test even from a
#    worktree (where ~/.config/nvimpager symlinks to the primary checkout).
LAZY="$HOME/.local/share/nvim/lazy"
if [ -d "$LAZY" ] && [ -n "$(ls -A "$LAZY" 2>/dev/null)" ]; then
  cfgdir=$(mktemp -d /tmp/nvimpager-cfg.XXXXXX)
  trap 'rm -f "$lua_script"; rm -rf "$cfgdir"' EXIT
  mkdir -p "$cfgdir/nvimpager"
  ln -s "$INIT" "$cfgdir/nvimpager/init.lua"
  if ! out=$(printf 'local x = 1\n' | XDG_CONFIG_HOME="$cfgdir" nvimpager -c 2>/tmp/nvimpager-color-err); then
    echo "❌ nvimpager cat-mode (color) exited non-zero:"
    cat /tmp/nvimpager-color-err
    fail=1
  elif ! printf '%s' "$out" | grep -q '38;2;'; then
    echo "❌ nvimpager cat-mode did not emit the theme's 24-bit palette (38;2;)"
    fail=1
  fi
fi

[ $fail -eq 0 ] && echo "✅ nvimpager smoke passed"
exit $fail
