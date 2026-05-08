#!/opt/homebrew/bin/bash
# Render every .mmd file in the repo to a co-located .svg.
# Skips files whose .svg is already newer than the .mmd source.
# Re-run after editing any .mmd diagram.

set -euo pipefail

cd "$(dirname "$0")/.."
shopt -s nullglob

command -v mmdc >/dev/null || { echo "mmdc not found — run 'mise install'"; exit 1; }

count=0
skipped=0
while IFS= read -r -d '' mmd; do
  svg="${mmd%.mmd}.svg"
  if [ -f "$svg" ] && [ "$svg" -nt "$mmd" ]; then
    skipped=$((skipped + 1))
    continue
  fi
  mmdc -i "$mmd" -o "$svg" -q
  echo "OK $(basename "$mmd") -> $(basename "$svg")"
  count=$((count + 1))
done < <(find . -path ./.claude/worktrees -prune -o -name '*.mmd' -print0)

if [ "$count" -eq 0 ] && [ "$skipped" -eq 0 ]; then
  echo "No .mmd files found."
  exit 0
fi
[ "$skipped" -gt 0 ] && echo "Skipped $skipped up-to-date diagram(s)."
[ "$count" -gt 0 ] && echo "Rendered $count diagram(s)."
