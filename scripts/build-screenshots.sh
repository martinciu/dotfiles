#!/opt/homebrew/bin/bash
# Regenerate -hero and -thumb derivatives for every docs/images/example_*.png source.
# Sources: docs/images/example_<tool>.png  (3176x1920 retina captures)
# Outputs: docs/images/example_<tool>-hero.png   (1600px longest side)
#          docs/images/example_<tool>-thumb.png  (800px longest side)
# Re-run after swapping a screenshot. Requires `sips` (macOS native).

set -euo pipefail

cd "$(dirname "$0")/.."
shopt -s nullglob

command -v sips >/dev/null || { echo "sips not found (macOS only)"; exit 1; }

count=0
for src in docs/images/example_*.png; do
  case "$src" in *-hero.png|*-thumb.png) continue ;; esac
  base="${src%.png}"
  sips -Z 1600 "$src" --out "${base}-hero.png"  >/dev/null
  sips -Z  800 "$src" --out "${base}-thumb.png" >/dev/null
  echo "OK $(basename "$src") -> -hero, -thumb"
  count=$((count + 1))
done

[ "$count" -gt 0 ] || { echo "No docs/images/example_*.png sources found."; exit 1; }
echo "Rebuilt $count screenshot(s)."
