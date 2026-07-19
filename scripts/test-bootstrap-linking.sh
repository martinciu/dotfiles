#!/opt/homebrew/bin/bash
# Smoke test for bootstrap.sh's mixed-dir helpers (#370).
# Extracts the helper functions from bootstrap.sh (it can't be sourced
# whole — it runs `brew bundle` at top level) and exercises them against
# a scratch git repo standing in for $DOTFILES plus a scratch target dir
# standing in for $HOME. Asserts:
#   - gitignored / untracked repo-side files are never symlinked (#370)
#   - tracked files link; tracked dirs whole-dir-symlink; *.template skipped
#   - a real (non-symlink) destination dir is left alone
#   - tracked-but-deleted entries skip without error
#   - rescue_in_repo still migrates repo→home when the target is absent
#   - both-copies-present warns and mutates neither file
#   - a $HOME symlink resolving into the repo is materialized (same bytes)
#   - a dangling $HOME symlink into the repo is removed
#   - a symlink pointing outside the repo is left alone

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- extract helpers from bootstrap.sh
eval "$(sed -n \
  -e '/^link() {/,/^}/p' \
  -e '/^prepare_real_dir() {/,/^}/p' \
  -e '/^rescue_in_repo() {/,/^}/p' \
  -e '/^link_tracked_entries() {/,/^}/p' \
  -e '/^seed_local() {/,/^}/p' \
  "$REPO_ROOT/bootstrap.sh")"

# Plain stand-ins for the Nerd Font glyph vars the helpers echo, so
# assertions can grep for them.
G_OK='[ok]'; G_LINK='[ln]'; G_BACKUP='[bak]'; G_SKIP='[skip]'
G_TRASH='[rm]'; G_MOVE='[mv]'; G_SEED='[seed]'; G_WARN='[warn]'

TMP=$(mktemp -d)
TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

DOTFILES="$TMP/repo" # the extracted helpers read this global
HOME_DIR="$TMP/home"
TOOL_DST="$HOME_DIR/.config/tool"

git init -q "$DOTFILES"
git -C "$DOTFILES" config user.email t@t.t
git -C "$DOTFILES" config user.name t

mkdir -p "$DOTFILES/.config/tool/subdir"
echo "tracked" > "$DOTFILES/.config/tool/tracked.conf"
echo "sub"     > "$DOTFILES/.config/tool/subdir/file.conf"
echo "tmpl"    > "$DOTFILES/.config/tool/seed.conf.template"
echo "deleted" > "$DOTFILES/.config/tool/deleted.conf"
echo "ignored.conf" > "$DOTFILES/.gitignore"
git -C "$DOTFILES" add -A
git -C "$DOTFILES" commit -qm fixture

echo "SECRET" > "$DOTFILES/.config/tool/ignored.conf"   # gitignored
echo "cruft"  > "$DOTFILES/.config/tool/untracked.conf" # untracked
rm "$DOTFILES/.config/tool/deleted.conf"                # tracked, deleted

fail=0
check() {
  local desc="$1"; shift
  if "$@"; then
    echo "  ok: $desc"
  else
    echo "FAIL: $desc" >&2
    fail=1
  fi
}

# --- link_tracked_entries ------------------------------------------------
mkdir -p "$TOOL_DST"
link_tracked_entries ".config/tool" "$TOOL_DST"

check "tracked file is symlinked" \
      [ "$(readlink "$TOOL_DST/tracked.conf" 2>/dev/null)" = "$DOTFILES/.config/tool/tracked.conf" ]
check "tracked dir is whole-dir-symlinked" \
      [ "$(readlink "$TOOL_DST/subdir" 2>/dev/null)" = "$DOTFILES/.config/tool/subdir" ]
check "gitignored file is NOT linked (#370)" [ ! -L "$TOOL_DST/ignored.conf" ]
check "untracked file is NOT linked" [ ! -L "$TOOL_DST/untracked.conf" ]
check "*.template is skipped" [ ! -e "$TOOL_DST/seed.conf.template" ]
check "tracked-but-deleted entry is skipped without error" [ ! -L "$TOOL_DST/deleted.conf" ]

# Destination that is already a real dir must be left alone (the caller
# handles it recursively — fish/conf.d case).
TOOL2_DST="$HOME_DIR/.config/tool2"
mkdir -p "$DOTFILES/.config/tool2/realdir" "$TOOL2_DST/realdir"
echo "inner" > "$DOTFILES/.config/tool2/realdir/inner.conf"
git -C "$DOTFILES" add -A
git -C "$DOTFILES" commit -qm tool2
link_tracked_entries ".config/tool2" "$TOOL2_DST"
check "real destination dir still a dir" [ -d "$TOOL2_DST/realdir" ]
check "real destination dir not replaced by symlink" [ ! -L "$TOOL2_DST/realdir" ]

# --- rescue_in_repo ------------------------------------------------------
RESCUE_DST="$HOME_DIR/.config/fishlike"
mkdir -p "$RESCUE_DST"

# Normal migration: repo-side real file, target absent ⇒ move.
echo "LIVE" > "$DOTFILES/.config/tool/migrate.conf"
rescue_in_repo "$DOTFILES/.config/tool/migrate.conf" "$RESCUE_DST/migrate.conf"
check "migration moves repo copy to target" [ -f "$RESCUE_DST/migrate.conf" ]
check "migration removes repo copy" [ ! -e "$DOTFILES/.config/tool/migrate.conf" ]

# Both copies exist ⇒ warn, mutate nothing.
echo "STALE" > "$DOTFILES/.config/tool/both.conf"
echo "REAL"  > "$RESCUE_DST/both.conf"
out=$(rescue_in_repo "$DOTFILES/.config/tool/both.conf" "$RESCUE_DST/both.conf")
check "both-exist emits warning" grep -q '\[warn\]' <<<"$out"
check "both-exist leaves repo copy in place" \
      [ "$(cat "$DOTFILES/.config/tool/both.conf")" = "STALE" ]
check "both-exist leaves target untouched" \
      [ "$(cat "$RESCUE_DST/both.conf")" = "REAL" ]

# Live symlink into the repo ⇒ materialize (#370 heal), then warn.
echo "KEYS" > "$DOTFILES/.config/tool/stale-secrets.conf"
ln -s "$DOTFILES/.config/tool/stale-secrets.conf" "$RESCUE_DST/secrets.conf"
out=$(rescue_in_repo "$DOTFILES/.config/tool/stale-secrets.conf" "$RESCUE_DST/secrets.conf")
check "healed target is a real file" [ -f "$RESCUE_DST/secrets.conf" ]
check "healed target is not a symlink" [ ! -L "$RESCUE_DST/secrets.conf" ]
check "healed bytes identical" \
      cmp -s "$DOTFILES/.config/tool/stale-secrets.conf" "$RESCUE_DST/secrets.conf"
check "repo-side copy untouched by heal" [ -f "$DOTFILES/.config/tool/stale-secrets.conf" ]
check "heal then warns about stale repo copy" grep -q '\[warn\]' <<<"$out"

# Dangling symlink into the repo ⇒ removed (seed_local re-seeds later).
ln -s "$DOTFILES/.config/tool/gone.conf" "$RESCUE_DST/dangling.conf"
rescue_in_repo "$DOTFILES/.config/tool/gone.conf" "$RESCUE_DST/dangling.conf"
check "dangling repo symlink removed" [ ! -L "$RESCUE_DST/dangling.conf" ]

# Symlink pointing OUTSIDE the repo ⇒ left alone (deliberate user setup).
echo "x" > "$TMP/elsewhere.conf"
ln -s "$TMP/elsewhere.conf" "$RESCUE_DST/foreign.conf"
rescue_in_repo "$DOTFILES/.config/tool/nonexistent.conf" "$RESCUE_DST/foreign.conf"
check "symlink outside repo left alone" \
      [ "$(readlink "$RESCUE_DST/foreign.conf")" = "$TMP/elsewhere.conf" ]

[ $fail -eq 0 ] && { echo "PASS"; exit 0; } || exit 1
