#!/usr/bin/env bash
# Smoke test for the nvim/LazyVim setup.
# Asserts plugins install cleanly and lazy reports no errors.
set -euo pipefail

echo "==> Lazy! sync (headless)"
nvim --headless "+Lazy! sync" "+qa"

echo
echo "==> checkhealth lazy (headless)"
out=$(nvim --headless "+checkhealth lazy" "+qa" 2>&1)
echo "$out"
if printf '%s' "$out" | grep -E "^- ERROR" >/dev/null; then
  echo
  echo "FAIL: checkhealth lazy reported ERROR"
  exit 1
fi

echo
echo "OK"
