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
