#!/opt/homebrew/bin/bash
# Render every .tape file under docs/tapes/ to a co-located .gif + .webm.
# Skips a tape if both outputs are newer than the .tape source.
# Re-run after editing any .tape.

set -euo pipefail

cd "$(dirname "$0")/.."
shopt -s nullglob

command -v vhs >/dev/null || { echo "vhs not found — 'brew bundle' to install"; exit 1; }

count=0
skipped=0
for tape in docs/tapes/*.tape; do
  gif="${tape%.tape}.gif"
  webm="${tape%.tape}.webm"
  if [ -f "$gif" ] && [ -f "$webm" ] && [ "$gif" -nt "$tape" ] && [ "$webm" -nt "$tape" ]; then
    skipped=$((skipped + 1))
    continue
  fi
  vhs "$tape"
  echo "OK $(basename "$tape") -> .gif, .webm"
  count=$((count + 1))
done

if [ "$count" -eq 0 ] && [ "$skipped" -eq 0 ]; then
  echo "No .tape files found under docs/tapes/."
  exit 0
fi
[ "$skipped" -gt 0 ] && echo "Skipped $skipped up-to-date tape(s)." || true
[ "$count" -gt 0 ] && echo "Rendered $count tape(s)." || true
