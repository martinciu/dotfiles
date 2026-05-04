#!/opt/homebrew/bin/bash
# Smoke test for the [pre-remove] save-shared hook in
# .config/worktrunk/config.toml. Extracts the hook command from
# config.toml, substitutes the {{ primary_worktree_path }} template,
# and exercises it in a temp repo. Asserts:
#   - new files in worktree get copied to primary
#   - primary's pre-existing files are NOT clobbered
#   - missing dirs in worktree are skipped (not errors)

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$DOTFILES/.config/worktrunk/config.toml"

command -v rsync >/dev/null || { echo "FAIL: rsync not installed" >&2; exit 1; }

# Extract the save-shared hook command from config.toml.
# Strip the `save-shared = "…"` wrapper, then un-escape TOML's `\"` so
# the bash-c invocation below sees real quote characters (not literal
# backslash-quotes that would end up inside the path argument).
hook_cmd=$(grep -E '^save-shared = ' "$CONFIG" | sed -E 's/^save-shared = "(.*)"$/\1/; s/\\"/"/g')
if [ -z "$hook_cmd" ]; then
  echo "FAIL: save-shared hook not found in $CONFIG" >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PRIMARY="$TMPDIR/primary"
WORKTREE="$TMPDIR/worktree"

# Primary has an existing spec that must NOT be clobbered.
mkdir -p "$PRIMARY/.superpowers/specs"
echo "ORIGINAL" > "$PRIMARY/.superpowers/specs/keep.md"

# Worktree has: a diverged copy of keep.md (must be dropped),
# a new spec (must land in primary), and a new autonomo log in
# a dir that primary doesn't yet have.
mkdir -p "$WORKTREE/.superpowers/specs"
echo "DIVERGED" > "$WORKTREE/.superpowers/specs/keep.md"
echo "NEW SPEC" > "$WORKTREE/.superpowers/specs/new.md"
mkdir -p "$WORKTREE/.autonomo"
echo "log line" > "$WORKTREE/.autonomo/run-1.log"

# Substitute the template variable, then run the hook in worktree's cwd.
substituted="${hook_cmd//\{\{ primary_worktree_path \}\}/$PRIMARY}"
( cd "$WORKTREE" && bash -c "$substituted" )

fail=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok:   $desc"
  else
    echo "FAIL: $desc — expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

check "primary's keep.md is unchanged" \
      "ORIGINAL" \
      "$(cat "$PRIMARY/.superpowers/specs/keep.md" 2>/dev/null)"
check "primary's new.md was created with worktree content" \
      "NEW SPEC" \
      "$(cat "$PRIMARY/.superpowers/specs/new.md" 2>/dev/null)"
check "primary's .autonomo/run-1.log was created" \
      "log line" \
      "$(cat "$PRIMARY/.autonomo/run-1.log" 2>/dev/null)"

[ $fail -eq 0 ] && { echo "PASS"; exit 0; } || exit 1
