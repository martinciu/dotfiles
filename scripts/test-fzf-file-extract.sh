#!/usr/bin/env bash
# Smoke tests for tmux-fzf-file's path-extraction logic.
# Tests the script's --extract-only mode (stdin → candidate paths on stdout)
# so we can feed fixtures without spinning up tmux.
set -u

REPO="$PROJECTS_HOME/dotfiles"
EXTRACT="$REPO/.config/tmux/bin/tmux-fzf-file"

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

assert_not_contains() {
  local got="$1" needle="$2" desc="$3"
  if printf '%s' "$got" | grep -q -F -- "$needle"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc (should NOT contain '$needle')")
    echo "  FAIL  $desc"
  else
    pass=$((pass+1))
    echo "  PASS  $desc"
  fi
}

echo
echo "tmux-fzf-file --extract-only"
echo "─────────────────────────────"

if [ ! -x "$EXTRACT" ]; then
  echo "  SKIP — $EXTRACT not present yet"
else
  # Set up a fake repo that exists on disk so the existence-filter passes.
  fake_root=$(mktemp -d)
  mkdir -p "$fake_root/lib"
  : > "$fake_root/lib/foo.rb"
  : > "$fake_root/lib/bar.rb"
  : > "$fake_root/README.md"

  # ── OSC 8 fixture (Claude Code style) ──
  osc8=$'\x1b]8;id=abc;file://'"$fake_root"$'/lib/foo.rb\x1b\\foo.rb\x1b]8;;\x1b\\'
  out=$(printf '%s\n' "$osc8" | "$EXTRACT" --extract-only "$fake_root")
  assert_contains "$out" "$fake_root/lib/foo.rb" "OSC 8 file:// URL is extracted to absolute path"

  # ── Plain path:line fixture (rg/grep style) ──
  out=$(printf 'lib/bar.rb:42: matched line\n' | "$EXTRACT" --extract-only "$fake_root")
  assert_contains "$out" "$fake_root/lib/bar.rb:42" "relative path:line resolves against cwd"

  # ── Path:line:col fixture ──
  out=$(printf 'lib/foo.rb:7:13: another match\n' | "$EXTRACT" --extract-only "$fake_root")
  assert_contains "$out" "$fake_root/lib/foo.rb:7:13" "path:line:col extracted intact"

  # ── Bare existing file (no line/col) ──
  out=$(printf 'see README.md for details\n' | "$EXTRACT" --extract-only "$fake_root")
  assert_contains "$out" "$fake_root/README.md" "bare existing path extracted"

  # ── Non-existent path is filtered out ──
  out=$(printf 'lib/does_not_exist.rb:1: ghost\n' | "$EXTRACT" --extract-only "$fake_root")
  assert_not_contains "$out" "does_not_exist" "non-existent path is filtered out"

  # ── host:port should NOT be matched as path:line ──
  out=$(printf 'connecting to 127.0.0.1:8080 for thing\n' | "$EXTRACT" --extract-only "$fake_root")
  assert_not_contains "$out" "127.0.0.1:8080" "host:port is not a file:line"

  # ── Absolute path:line fixture ──
  out=$(printf '%s/lib/foo.rb:10: hello\n' "$fake_root" | "$EXTRACT" --extract-only "$fake_root")
  assert_contains "$out" "$fake_root/lib/foo.rb:10" "absolute path:line passes through unchanged"

  # ── No duplicates when the same path appears via OSC 8 and bare text ──
  mixed=$(printf '%s\nlib/foo.rb:1\n' "$osc8")
  out=$(printf '%s\n' "$mixed" | "$EXTRACT" --extract-only "$fake_root")
  count=$(printf '%s\n' "$out" | grep -c "lib/foo.rb" || true)
  assert_eq "$count" "2" "OSC 8 and bare:line are both kept (different line specs are different candidates)"

  rm -rf "$fake_root"
fi

# ── Summary ─────────────────────────────────
echo
echo "─────────────────"
total=$((pass+fail))
echo "$pass / $total passed"
if [ "$fail" -gt 0 ]; then
  echo
  for msg in "${fail_msgs[@]}"; do
    printf '%s\n' "$msg"
  done
  exit 1
fi
