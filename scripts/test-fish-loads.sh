#!/opt/homebrew/bin/bash
# Smoke test: every fish config file parses, and a full fish session
# starts without errors when the repo's .config/fish is loaded.
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
FISH_DIR="$DOTFILES/.config/fish"

if ! command -v fish >/dev/null 2>&1; then
  echo "⏭️  fish not installed — skipping (brew install fish)"
  exit 0
fi

if [ ! -d "$FISH_DIR" ]; then
  echo "⏭️  $FISH_DIR not present yet — skipping"
  exit 0
fi

# 1. Parse-check every tracked .fish file (no execution).
fail=0
while IFS= read -r -d '' f; do
  if ! fish -n < "$f" 2>/tmp/fish-parse-err; then
    echo "❌ parse error in $f:"
    cat /tmp/fish-parse-err
    fail=1
  fi
done < <(find "$FISH_DIR" -name '*.fish' -print0)

# 2. Full-session smoke: spawn fish with HOME pointing at a fixture that
#    symlinks our config in. Verify exit code and a representative alias
#    is defined.
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/.config"
ln -s "$FISH_DIR" "$fixture/.config/fish"
if ! HOME="$fixture" fish -c 'functions -q cat; and functions -q ls; and functions -q vim' \
    2>/tmp/fish-smoke-err; then
  echo "❌ fish session smoke failed:"
  cat /tmp/fish-smoke-err
  fail=1
fi

[ $fail -eq 0 ] && echo "✅ fish config loads clean"
exit $fail
