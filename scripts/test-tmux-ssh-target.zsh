#!/usr/bin/env zsh
# Tests for _tmux_record_ssh_target and _tmux_clear_ssh_target.
# Keep the inline function bodies in sync with .zshrc.
# Run: zsh scripts/test-tmux-ssh-target.zsh
set -u

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

assert_no_call() {
  local -a haystack=("${(@P)1}")
  local needle="$2" desc="$3"
  local hit
  for hit in "${haystack[@]}"; do
    if [[ "$hit" == *"$needle"* ]]; then
      fail=$((fail+1))
      fail_msgs+=("FAIL  $desc"$'\n'"        unexpected call: '$hit'")
      echo "  FAIL  $desc"
      return
    fi
  done
  pass=$((pass+1)); echo "  PASS  $desc"
}

# ── mocks ────────────────────────────────────────────────────────────────────
# `tmux` is shadowed by a zsh function so the SUT's tmux invocations are
# captured without touching a real tmux server. Pane-variable state is held
# in _mock_pane_vars; refresh-client is a no-op recorder.
typeset -ga _mock_tmux_calls=()
typeset -gA _mock_pane_vars=()

tmux() {
  _mock_tmux_calls+=("$*")
  case "$1" in
    set)
      shift
      [[ "$1" == "-p" ]] && shift
      if [[ "$1" == "-u" ]]; then
        shift
        unset "_mock_pane_vars[$1]"
      else
        local name="$1"; shift
        _mock_pane_vars[$name]="$*"
      fi
      ;;
    show)
      shift
      [[ "$1" == "-p" ]] && shift
      [[ "$1" == "-v" ]] && shift
      printf '%s' "${_mock_pane_vars[$1]:-}"
      ;;
    refresh-client) ;;  # recorded but otherwise a no-op
  esac
}

# `ssh` is shadowed too. -G mode prints the canned response and exits with
# the canned status. Other invocations are no-ops (we never run real ssh).
typeset -ga _mock_ssh_calls=()
typeset -g _mock_ssh_g_response=""
typeset -g _mock_ssh_g_exit=0

ssh() {
  _mock_ssh_calls+=("$*")
  if [[ "$1" == "-G" ]]; then
    [[ -n "$_mock_ssh_g_response" ]] && printf '%s\n' "$_mock_ssh_g_response"
    return $_mock_ssh_g_exit
  fi
  return 0
}

reset_state() {
  _mock_tmux_calls=()
  _mock_ssh_calls=()
  _mock_pane_vars=()
  _mock_ssh_g_response=""
  _mock_ssh_g_exit=0
}

# ── functions under test (keep in sync with .zshrc) ──────────────────────────
_tmux_record_ssh_target() {
  [[ -z ${TMUX:-} ]] && return
  local -a tokens=(${=1})
  [[ ${tokens[1]:-} == ssh ]] || return
  local resolved
  resolved=$(eval "ssh -G ${1#ssh}" 2>/dev/null) || return
  local host user
  host=${${(M)${(f)resolved}:#hostname *}#hostname }
  user=${${(M)${(f)resolved}:#user *}#user }
  [[ -n $user && -n $host ]] || return
  tmux set -p @ssh_target "$user@$host"
  tmux refresh-client -S
}

_tmux_clear_ssh_target() {
  [[ -z ${TMUX:-} ]] && return
  [[ -z $(tmux show -p -v @ssh_target 2>/dev/null) ]] && return
  tmux set -p -u @ssh_target
  tmux refresh-client -S
}

# ── tests: _tmux_record_ssh_target (preexec) ─────────────────────────────────
echo
echo "_tmux_record_ssh_target"
echo "──────────────────────"

# 1. TMUX unset → no-op
reset_state
unset TMUX
_tmux_record_ssh_target "ssh foo@bar"
assert_no_call _mock_tmux_calls "set -p @ssh_target" \
  "TMUX unset → no tmux set call"

# Switch to "tmux running" mode for the remaining tests.
export TMUX=fake

# 2. Non-ssh command → no-op
reset_state
_tmux_record_ssh_target "ls -la"
assert_no_call _mock_tmux_calls "set -p @ssh_target" \
  "Non-ssh command → no tmux set call"

# 3. ssh foo@bar → @ssh_target=foo@bar
reset_state
_mock_ssh_g_response=$'user foo\nhostname bar\nport 22'
_tmux_record_ssh_target "ssh foo@bar"
assert_eq "${_mock_pane_vars[@ssh_target]:-}" "foo@bar" \
  "ssh foo@bar → @ssh_target = foo@bar"

# 4. ssh studio (alias) → @ssh_target = canonical user@hostname
reset_state
_mock_ssh_g_response=$'hostname studio.local\nuser martinciu\nport 22'
_tmux_record_ssh_target "ssh studio"
assert_eq "${_mock_pane_vars[@ssh_target]:-}" "martinciu@studio.local" \
  "ssh studio → canonical martinciu@studio.local"

# 5. refresh-client -S is called after a successful ssh detection
reset_state
_mock_ssh_g_response=$'user foo\nhostname bar'
_tmux_record_ssh_target "ssh foo@bar"
refresh_seen=0
for c in "${_mock_tmux_calls[@]}"; do
  [[ "$c" == "refresh-client -S" ]] && refresh_seen=1
done
assert_eq "$refresh_seen" "1" \
  "ssh detection triggers refresh-client -S"

# 6. ssh-add → no-op (first-token equality, not prefix)
reset_state
_tmux_record_ssh_target "ssh-add ~/.ssh/id_ed25519"
assert_no_call _mock_tmux_calls "set -p @ssh_target" \
  "ssh-add → no tmux set call"

# 7. ssh-keygen → no-op
reset_state
_tmux_record_ssh_target "ssh-keygen -t ed25519 -C foo"
assert_no_call _mock_tmux_calls "set -p @ssh_target" \
  "ssh-keygen → no tmux set call"

# 8. ssh -G failure (resolver returns non-zero) → no @ssh_target set
reset_state
_mock_ssh_g_exit=255
_mock_ssh_g_response=""
_tmux_record_ssh_target "ssh garbledhost"
assert_no_call _mock_tmux_calls "set -p @ssh_target" \
  "ssh -G failure → no tmux set call"

# 9. ssh -G returns no user/hostname (only port) → no @ssh_target set
reset_state
_mock_ssh_g_response=$'port 22'
_tmux_record_ssh_target "ssh foo"
assert_no_call _mock_tmux_calls "set -p @ssh_target" \
  "ssh -G with no user/hostname → no tmux set call"

# ── tests: _tmux_clear_ssh_target (precmd) ───────────────────────────────────
echo
echo "_tmux_clear_ssh_target"
echo "─────────────────────"

# 10. TMUX unset → no-op
reset_state
unset TMUX
_tmux_clear_ssh_target
assert_no_call _mock_tmux_calls "set -p -u @ssh_target" \
  "TMUX unset → no tmux unset call"

export TMUX=fake

# 11. @ssh_target empty → no-op (early exit, no spurious refresh)
reset_state
_tmux_clear_ssh_target
assert_no_call _mock_tmux_calls "set -p -u @ssh_target" \
  "@ssh_target empty → no tmux unset call"
assert_no_call _mock_tmux_calls "refresh-client -S" \
  "@ssh_target empty → no refresh-client call"

# 12. @ssh_target set → unset + refresh
reset_state
_mock_pane_vars[@ssh_target]="martinciu@studio.local"
_tmux_clear_ssh_target
assert_eq "${_mock_pane_vars[@ssh_target]:-EMPTY}" "EMPTY" \
  "@ssh_target set → unset by clear hook"
refresh_seen=0
for c in "${_mock_tmux_calls[@]}"; do
  [[ "$c" == "refresh-client -S" ]] && refresh_seen=1
done
assert_eq "$refresh_seen" "1" \
  "clear hook triggers refresh-client -S"

# ── summary ──────────────────────────────────────────────────────────────────
echo
echo "──────────────────────"
echo "passed: $pass"
echo "failed: $fail"
if (( fail > 0 )); then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
