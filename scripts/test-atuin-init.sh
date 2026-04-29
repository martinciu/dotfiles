#!/usr/bin/env bash
# Smoke test for atuin's zsh init wiring.
# Asserts that .zshrc registers the custom Ctrl-X Ctrl-R widget that
# launches atuin in full-screen mode (the only piece of custom logic
# we add — atuin's own bindings are atuin's responsibility).
set -euo pipefail

if ! command -v atuin >/dev/null 2>&1; then
  echo "SKIP: atuin not installed (run 'brew install atuin')"
  exit 0
fi

echo "==> Asserting Ctrl-X Ctrl-R is bound to atuin-search-fullscreen"
out=$(zsh -i -c "bindkey '^X^R'" 2>&1)
echo "$out"
if printf '%s' "$out" | grep -q atuin-search-fullscreen; then
  echo
  echo "OK"
else
  echo
  echo "FAIL: Ctrl-X Ctrl-R is not bound to atuin-search-fullscreen"
  exit 1
fi
