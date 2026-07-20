#!/opt/homebrew/bin/bash
# Asserts shape invariants of .config/tmux/tmux.conf that tmux itself won't
# catch (it happily accepts duplicate option assignments). Historical: until
# #376 this also guarded continuum's status-right-before-TPM ordering (#357);
# the plugin is gone, and the ordering constraint with it.
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

  count="$(grep -c '^set -g status-right "' "$CONF")"
  if [ "$count" -eq 1 ]; then
    record_pass "status-right assigned exactly once"
  else
    record_fail "status-right assigned exactly once" "found $count assignments"
  fi

  # TEMP-DISABLED(moshi): the phone-twin hooks are commented out in
  # tmux.conf (#374) while the window-size interaction is rethought (#375).
  # Uncomment these assertions together with the hooks — they're on #375's
  # re-enable checklist.
  #
  # tpm_run_line="$(grep -n "^run '~/.config/tmux/plugins/tpm/tpm'" "$CONF" | head -1 | cut -d: -f1)"
  #
  # hook_line="$(grep -n '^set-hook -g client-attached' "$CONF" | head -1 | cut -d: -f1)"
  # if [ -n "$hook_line" ] && grep -q 'tmux-phone-attach' "$CONF"; then
  #   record_pass "client-attached phone hook present"
  # else
  #   record_fail "client-attached phone hook present" "set-hook -g client-attached … tmux-phone-attach not found (#366)"
  # fi
  #
  # if [ -n "$hook_line" ] && [ -n "$tpm_run_line" ] && [ "$hook_line" -lt "$tpm_run_line" ]; then
  #   record_pass "phone hook (line $hook_line) before TPM run (line $tpm_run_line)"
  # else
  #   record_fail "phone hook before TPM run" "hook line: '${hook_line:-none}', TPM run line: '${tpm_run_line:-none}'"
  # fi
  #
  # if grep -q '^set -g status-left ".*tmux-statusbar-guard' "$CONF"; then
  #   record_pass "status-left includes the clobber guard (#372)"
  # else
  #   record_fail "status-left includes the clobber guard" "tmux-statusbar-guard #() not found in status-left (#372)"
  # fi
  #
  # sess_hook_line="$(grep -n '^set-hook -g client-session-changed' "$CONF" | head -1 | cut -d: -f1)"
  # if [ -n "$sess_hook_line" ] && grep -q "client-session-changed.*tmux-phone-attach" "$CONF"; then
  #   record_pass "client-session-changed phone hook present (#372)"
  # else
  #   record_fail "client-session-changed phone hook present" "set-hook -g client-session-changed … tmux-phone-attach not found (#372)"
  # fi
  #
  # if [ -n "$sess_hook_line" ] && [ -n "$tpm_run_line" ] && [ "$sess_hook_line" -lt "$tpm_run_line" ]; then
  #   record_pass "session-changed hook (line $sess_hook_line) before TPM run (line $tpm_run_line)"
  # else
  #   record_fail "session-changed hook before TPM run" "hook line: '${sess_hook_line:-none}', TPM run line: '${tpm_run_line:-none}'"
  # fi
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
