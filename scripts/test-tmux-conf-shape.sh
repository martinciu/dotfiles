#!/opt/homebrew/bin/bash
# Asserts load-order shape of .config/tmux/tmux.conf that tmux itself won't
# catch. Key invariant: status-right must be assigned BEFORE the TPM `run`,
# because tmux-continuum prepends its auto-save hook to status-right at
# plugin load — assigning status-right after TPM wipes the hook and silently
# kills periodic auto-save (#357).
set -u

REPO="${REPO:-$PROJECTS_HOME/dotfiles}"
CONF="$REPO/.config/tmux/tmux.conf"

pass=0
fail=0
fail_msgs=()

record_pass() { pass=$((pass+1)); echo "  PASS  $1"; }
record_fail() {
  fail=$((fail+1))
  fail_msgs+=("FAIL  $1"$'\n'"        $2")
  echo "  FAIL  $1"
}

echo
echo "tmux.conf shape"
echo "───────────────"

if [ ! -f "$CONF" ]; then
  record_fail "tmux.conf present" "missing: $CONF"
else
  record_pass "tmux.conf present"

  status_right_line="$(grep -n '^set -g status-right "' "$CONF" | head -1 | cut -d: -f1)"
  tpm_run_line="$(grep -n "^run '~/.config/tmux/plugins/tpm/tpm'" "$CONF" | head -1 | cut -d: -f1)"

  count="$(grep -c '^set -g status-right "' "$CONF")"
  if [ "$count" -eq 1 ]; then
    record_pass "status-right assigned exactly once"
  else
    record_fail "status-right assigned exactly once" "found $count assignments"
  fi

  if [ -z "$status_right_line" ] || [ -z "$tpm_run_line" ]; then
    record_fail "status-right before TPM run" "status-right line: '${status_right_line:-none}', TPM run line: '${tpm_run_line:-none}'"
  elif [ "$status_right_line" -lt "$tpm_run_line" ]; then
    record_pass "status-right (line $status_right_line) before TPM run (line $tpm_run_line)"
  else
    record_fail "status-right before TPM run" "status-right at line $status_right_line, TPM run at line $tpm_run_line — continuum's auto-save hook gets clobbered (#357)"
  fi

  if grep -q "^set -g @continuum-save-interval '15'" "$CONF"; then
    record_pass "@continuum-save-interval pinned to 15"
  else
    record_fail "@continuum-save-interval pinned to 15" "line not found in $CONF"
  fi

  hook_line="$(grep -n '^set-hook -g client-attached' "$CONF" | head -1 | cut -d: -f1)"
  if [ -n "$hook_line" ] && grep -q 'tmux-phone-attach' "$CONF"; then
    record_pass "client-attached phone hook present"
  else
    record_fail "client-attached phone hook present" "set-hook -g client-attached … tmux-phone-attach not found (#366)"
  fi

  if [ -n "$hook_line" ] && [ -n "$tpm_run_line" ] && [ "$hook_line" -lt "$tpm_run_line" ]; then
    record_pass "phone hook (line $hook_line) before TPM run (line $tpm_run_line)"
  else
    record_fail "phone hook before TPM run" "hook line: '${hook_line:-none}', TPM run line: '${tpm_run_line:-none}'"
  fi

  if grep -q '^set -g status-left ".*tmux-statusbar-guard' "$CONF"; then
    record_pass "status-left includes the clobber guard (#372)"
  else
    record_fail "status-left includes the clobber guard" "tmux-statusbar-guard #() not found in status-left (#372)"
  fi

  sess_hook_line="$(grep -n '^set-hook -g client-session-changed' "$CONF" | head -1 | cut -d: -f1)"
  if [ -n "$sess_hook_line" ] && grep -q "client-session-changed.*tmux-phone-attach" "$CONF"; then
    record_pass "client-session-changed phone hook present (#372)"
  else
    record_fail "client-session-changed phone hook present" "set-hook -g client-session-changed … tmux-phone-attach not found (#372)"
  fi

  if [ -n "$sess_hook_line" ] && [ -n "$tpm_run_line" ] && [ "$sess_hook_line" -lt "$tpm_run_line" ]; then
    record_pass "session-changed hook (line $sess_hook_line) before TPM run (line $tpm_run_line)"
  else
    record_fail "session-changed hook before TPM run" "hook line: '${sess_hook_line:-none}', TPM run line: '${tpm_run_line:-none}'"
  fi
fi

echo
echo "───────────────────────────────────────"
echo "PASS: $pass    FAIL: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  for msg in "${fail_msgs[@]}"; do
    printf '%s\n' "$msg"
  done
  exit 1
fi
