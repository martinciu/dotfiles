#!/usr/bin/env zsh
# Unit tests for claude-tmux-window-name.
# Run: zsh scripts/test-claude-tmux-window-name.zsh
set -u

REPO="${PROJECTS_HOME:-$HOME/code}/dotfiles"
SCRIPT="$REPO/.config/tmux/bin/claude-tmux-window-name"

pass=0; fail=0; fail_msgs=()

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [[ "$got" == "$want" ]]; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        want: '$want'")
    echo "  FAIL  $desc"
  fi
}

# ── test harness ─────────────────────────────────────────────────────────────
# Each test sets up a fresh fake $HOME/.claude/sessions/ dir and a mock
# `tmux` shim on $PATH that records every invocation to $TMUX_CALLS.
setup_env() {
  TEST_HOME=$(mktemp -d)
  TMUX_CALLS="$TEST_HOME/tmux-calls.log"
  : > "$TMUX_CALLS"
  mkdir -p "$TEST_HOME/.claude/sessions"
  mkdir -p "$TEST_HOME/bin"
  cat > "$TEST_HOME/bin/tmux" <<'SHIM'
#!/usr/bin/env sh
printf '%s\0' "$@" >> "$TMUX_CALLS"
printf '\n' >> "$TMUX_CALLS"
SHIM
  chmod +x "$TEST_HOME/bin/tmux"
  HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH"
  export HOME PATH TMUX_CALLS
}

teardown_env() {
  rm -rf "$TEST_HOME"
  unset TEST_HOME TMUX_CALLS
}

run_script() {
  # Usage: run_script <mode> [stdin-json]
  local mode="$1" stdin="${2:-}"
  if [[ -n $stdin ]]; then
    printf '%s' "$stdin" | "$SCRIPT" "$mode"
  else
    "$SCRIPT" "$mode" </dev/null
  fi
}

# Count tmux invocations recorded in TMUX_CALLS (one per line).
tmux_call_count() {
  if [[ ! -s $TMUX_CALLS ]]; then echo 0; return; fi
  grep -c '' "$TMUX_CALLS"
}

# ── tests ────────────────────────────────────────────────────────────────────
echo
echo "claude-tmux-window-name"
echo "───────────────────────"

# 1. No $TMUX_PANE → no tmux call, exit 0.
setup_env
unset TMUX_PANE
run_script set '{"session_id":"any"}'
assert_eq "$(tmux_call_count)" "0" "no \$TMUX_PANE → script no-ops"
teardown_env

# ── summary ──────────────────────────────────────────────────────────────────
echo
echo "───────────────────────"
echo "passed: $pass"
echo "failed: $fail"
if (( fail > 0 )); then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
