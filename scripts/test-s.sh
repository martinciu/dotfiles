#!/usr/bin/env bash
# Smoke tests for bin/s.
# Invoked from scripts/test-helpers.sh; can also be run standalone.
#
# Manual smoke-test checklist (run these by hand after the suite passes):
#  1. Inside tmux session `dotfiles`, `s feature-x` -> new session
#     `dotfiles/feature-x` at the worktree path. Repeating `s feature-x`
#     -> switch-client to existing session, no second worktree created.
#  2. Outside tmux, `s` -> fzf picker -> pick `dotfiles` -> attach to
#     `dotfiles` session at ~/code/dotfiles.
#  3. Outside tmux, `s dotfiles feature-x` -> fresh `dotfiles/feature-x`
#     session with worktree at ~/code/dotfiles/.claude/worktrees/feature-x.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="$REPO/bin/s"

pass=0
fail=0
fail_msgs=()

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then
    pass=$((pass+1))
    echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        want: '$want'")
    echo "  FAIL  $desc"
  fi
}

assert_contains() {
  local got="$1" needle="$2" desc="$3"
  if printf '%s' "$got" | grep -q -F -- "$needle"; then
    pass=$((pass+1))
    echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        needle: '$needle'")
    echo "  FAIL  $desc"
  fi
}

echo
echo "bin/s"
echo "─────"

if [ ! -x "$S" ]; then
  echo "  SKIP — $S not present yet"
else
  # too many args -> usage
  out=$(env -u TMUX "$S" a b c 2>&1); rc=$?
  assert_eq "$rc" "1" "too many args -> exit 1"
  assert_contains "$out" "Usage:" "too many args -> usage on stderr"

  # ─── shim helpers ──────────────────────────
  # Each test creates a fresh shimdir, writes shims, and prepends to PATH.
  # Shims that record args write to "$shimdir/<name>.log".
  make_shimdir() { mktemp -d; }

  write_sesh_shim() {
    # $1 = shimdir, $2 = JSON to emit for `sesh list -c -j`
    local d="$1" json="$2"
    cat >"$d/sesh" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$d/sesh.log"
if [ "\$1" = "list" ]; then
  printf '%s\n' '$json'
  exit 0
fi
echo "sesh shim: unsupported args: \$*" >&2; exit 99
SHIM
    chmod +x "$d/sesh"
  }

  # ─── project lookup: not found ─────────────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/dotfiles"}]'
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" nope 2>&1); rc=$?
  assert_eq "$rc" "1" "explicit project not in sesh -> exit 1"
  assert_contains "$out" "no project named 'nope'" "explicit project not in sesh -> error message"
  rm -rf "$shimdir"

  # ─── project lookup: sesh missing -> meaningful error, not silent abort
  # Use a shimdir that shadows sesh (and jq/head) with nothing, but keep
  # system dirs so the zsh shebang still resolves. A no-op sesh shim that
  # exits non-zero simulates a broken/missing tool without stripping PATH.
  shimdir=$(make_shimdir)
  cat >"$shimdir/sesh" <<'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
  chmod +x "$shimdir/sesh"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" anything 2>&1); rc=$?
  assert_eq "$rc" "1" "sesh missing -> exit 1 (not 127)"
  assert_contains "$out" "no project named 'anything'" "sesh missing -> error message"
  rm -rf "$shimdir"
fi

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "test-s.sh passed: $pass"
echo "test-s.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
