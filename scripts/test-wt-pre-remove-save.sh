#!/opt/homebrew/bin/bash
# Smoke test for the [pre-remove] save-shared hook in
# .config/worktrunk/config.toml. Extracts the hook command from
# config.toml, substitutes the {{ primary_worktree_path }} and
# {{ branch }} templates, and exercises it against a real worktree.
# Asserts:
#   - new files in worktree get copied to primary
#   - primary's pre-existing files are NOT clobbered (no overwrite)
#   - new gitignored top-level dirs in worktree are created on primary
#     with their contents (the case issue #94 is about — e.g.
#     autonomo-workspace/ with no per-hook edit)

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$DOTFILES/.config/worktrunk/config.toml"

command -v wt >/dev/null || { echo "FAIL: wt not installed" >&2; exit 1; }

# Extract the save-shared hook command from config.toml.
# Strip the `save-shared = "…"` wrapper, then un-escape TOML's `\"` so
# bash -c below sees real quote characters.
hook_cmd=$(grep -E '^save-shared = ' "$CONFIG" | sed -E 's/^save-shared = "(.*)"$/\1/; s/\\"/"/g')
if [ -z "$hook_cmd" ]; then
  echo "FAIL: save-shared hook not found in $CONFIG" >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
# Use realpath so paths match what `wt` and `git` report (macOS symlinks
# /tmp → /private/tmp and /var/folders → /private/var/folders).
TMPDIR=$(cd "$TMPDIR" && pwd -P)

cleanup() {
  # Best-effort cleanup. --no-hooks skips the user's [pre-remove] hook
  # so cleanup doesn't re-run the very thing we just tested.
  if [ -n "${PRIMARY:-}" ] && [ -d "$PRIMARY" ]; then
    ( cd "$PRIMARY" && wt remove feature -y --no-hooks >/dev/null 2>&1 ) || true
  fi
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

PRIMARY="$TMPDIR/primary"
git init -q "$PRIMARY"
git -C "$PRIMARY" config user.email t@t.t
git -C "$PRIMARY" config user.name t
echo "tracked" > "$PRIMARY/tracked.txt"
cat > "$PRIMARY/.gitignore" <<'EOF'
.superpowers/
.autonomo/
autonomo-workspace/
EOF
git -C "$PRIMARY" add -A
git -C "$PRIMARY" commit -qm init

# Primary fixture: existing spec that must NOT be clobbered.
mkdir -p "$PRIMARY/.superpowers/specs"
echo "ORIGINAL" > "$PRIMARY/.superpowers/specs/keep.md"

# Create a real feature worktree via wt. -y bypasses approval prompts;
# --no-hooks suppresses the user's [post-start] (which would otherwise
# race with the worktree fixture writes below).
( cd "$PRIMARY" && wt switch --create feature -y --no-hooks >/dev/null 2>&1 )
WORKTREE="$PRIMARY/.claude/worktrees/feature"
[ -d "$WORKTREE" ] || { echo "FAIL: worktree not created at $WORKTREE" >&2; exit 1; }

# Worktree fixtures:
#   - diverged keep.md (must be DROPPED — primary's stays "ORIGINAL")
#   - new spec new.md (must MIGRATE to primary)
#   - new dir .autonomo/ with content (must MIGRATE — primary has no .autonomo/ yet)
#   - new dir autonomo-workspace/ with content (must MIGRATE — issue #94's case)
mkdir -p "$WORKTREE/.superpowers/specs"
echo "DIVERGED" > "$WORKTREE/.superpowers/specs/keep.md"
echo "NEW SPEC" > "$WORKTREE/.superpowers/specs/new.md"
mkdir -p "$WORKTREE/.autonomo"
echo "log line" > "$WORKTREE/.autonomo/run-1.log"
mkdir -p "$WORKTREE/autonomo-workspace/iter-1"
echo "trace" > "$WORKTREE/autonomo-workspace/iter-1/trace.json"

# Substitute template variables.
substituted="$hook_cmd"
substituted="${substituted//\{\{ primary_worktree_path \}\}/$PRIMARY}"
substituted="${substituted//\{\{ branch \}\}/feature}"

# Run the hook from inside the worktree (matches wt's pre-remove behavior:
# pre-remove "Runs in the worktree being removed").
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
check "primary's autonomo-workspace/iter-1/trace.json was created" \
      "trace" \
      "$(cat "$PRIMARY/autonomo-workspace/iter-1/trace.json" 2>/dev/null)"

[ $fail -eq 0 ] && { echo "PASS"; exit 0; } || exit 1
