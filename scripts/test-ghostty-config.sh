#!/opt/homebrew/bin/bash
# Smoke test: Ghostty parses the live config.ghostty without errors.
# Validates the symlinked-to-repo config plus machine-local includes
# (font.ghostty, theme.ghostty, etc.). Run after editing any tracked
# Ghostty config or modifying the includes via theme-set / font-set.
set -euo pipefail

if ! command -v ghostty >/dev/null 2>&1; then
  echo "⏭️  ghostty not installed — skipping (brew install --cask ghostty)"
  exit 0
fi

if out=$(ghostty +validate-config 2>&1); then
  echo "✅ ghostty config validates clean"
  exit 0
fi

echo "❌ ghostty config has errors:"
echo "$out"
exit 1
