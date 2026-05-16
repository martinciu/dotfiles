#!/opt/homebrew/bin/bash
# Smoke tests for tmux-agent-status-hook.
#
# Strategy: PATH-shim `tmux` to fake `display-message`, point
# XDG_CACHE_HOME at a sandbox, run the hook, inspect the result.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO/.config/tmux/bin/tmux-agent-status-hook"

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

setup() {
  local session="$1"
  SANDBOX=$(mktemp -d)
  mkdir -p "$SANDBOX/bin" "$SANDBOX/cache"
  cat > "$SANDBOX/bin/tmux" <<EOF
#!/opt/homebrew/bin/bash
[ "\$1" = "display-message" ] && printf '%s\n' "$session"
EOF
  chmod +x "$SANDBOX/bin/tmux"
  _SAVED_PATH="$PATH"
  export PATH="$SANDBOX/bin:$PATH"
  export XDG_CACHE_HOME="$SANDBOX/cache"
  export TMUX="dummy-socket,1234,0"
}

teardown() {
  PATH="$_SAVED_PATH"
  unset TMUX XDG_CACHE_HOME _SAVED_PATH
  rm -rf "$SANDBOX"
}

read_or_blank() {
  if [ -f "$1" ]; then cat "$1"; else echo "<MISSING>"; fi
}

echo
echo "tmux-agent-status-hook"
echo "──────────────────────"

if [ ! -x "$HOOK" ]; then
  echo "  SKIP — $HOOK not present yet"
else
  # Case 1: no TMUX env → no file written.
  SANDBOX=$(mktemp -d)
  mkdir -p "$SANDBOX/cache"
  ( unset TMUX; XDG_CACHE_HOME="$SANDBOX/cache" printf '{}' | "$HOOK" UserPromptSubmit )
  files=$(find "$SANDBOX/cache" -name '*.status' 2>/dev/null | wc -l | tr -d ' ')
  assert_eq "$files" "0" "1. no TMUX → no .status file written"
  rm -rf "$SANDBOX"

  # Case 2: empty session name from shim → no file.
  setup ''
  printf '{}' | "$HOOK" UserPromptSubmit
  files=$(find "$XDG_CACHE_HOME" -name '*.status' 2>/dev/null | wc -l | tr -d ' ')
  assert_eq "$files" "0" "2. empty session name → no .status file"
  teardown

  # Case 3: UserPromptSubmit + flat name → working.
  setup 'demo'
  printf '{}' | "$HOOK" UserPromptSubmit
  assert_eq "$(read_or_blank "$XDG_CACHE_HOME/tmux-agent-status/demo.status")" \
            "working" "3. UserPromptSubmit + flat → working"
  teardown

  # Case 4: PreToolUse + flat → working.
  setup 'demo'
  printf '{}' | "$HOOK" PreToolUse
  assert_eq "$(read_or_blank "$XDG_CACHE_HOME/tmux-agent-status/demo.status")" \
            "working" "4. PreToolUse + flat → working"
  teardown

  # Case 5: Stop + flat → done.
  setup 'demo'
  printf '{}' | "$HOOK" Stop
  assert_eq "$(read_or_blank "$XDG_CACHE_HOME/tmux-agent-status/demo.status")" \
            "done" "5. Stop + flat → done"
  teardown

  # Case 6: Notification + flat → done.
  setup 'demo'
  printf '{}' | "$HOOK" Notification
  assert_eq "$(read_or_blank "$XDG_CACHE_HOME/tmux-agent-status/demo.status")" \
            "done" "6. Notification + flat → done"
  teardown

  # Case 7: slash-bearing session → sanitized to _.
  setup 'dotfiles/231-tmux-agent-status'
  printf '{}' | "$HOOK" UserPromptSubmit
  assert_eq "$(read_or_blank "$XDG_CACHE_HOME/tmux-agent-status/dotfiles_231-tmux-agent-status.status")" \
            "working" "7a. session with / → sanitized to _"
  if [ -e "$XDG_CACHE_HOME/tmux-agent-status/dotfiles" ]; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  7b. unsanitized nested 'dotfiles/' dir should NOT exist")
    echo "  FAIL  7b. unsanitized nested 'dotfiles/' dir should NOT exist"
  else
    pass=$((pass+1))
    echo "  PASS  7b. no nested 'dotfiles/' dir created"
  fi
  teardown

  # Case 8: unknown event → no file.
  setup 'demo'
  printf '{}' | "$HOOK" Bogus
  files=$(find "$XDG_CACHE_HOME" -name '*.status' 2>/dev/null | wc -l | tr -d ' ')
  assert_eq "$files" "0" "8. unknown event → no file written"
  teardown
fi

echo
echo "──────────────────────────────"
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n\n' "${fail_msgs[@]}"
  exit 1
fi
