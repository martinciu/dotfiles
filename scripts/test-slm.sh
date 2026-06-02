#!/opt/homebrew/bin/bash
# Smoke test for the `slm` fish function (.config/fish/functions/slm.fish).
# Covers the deterministic no-server paths; the live happy-path is gated on
# oMLX being reachable (and SLM_API_KEY set) so CI (no oMLX) still passes.
set -uo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
SLM_FN="$DOTFILES/.config/fish/functions/slm.fish"

for tool in fish jq curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "⏭️  $tool not installed — skipping slm smoke"
    exit 0
  fi
done

if [ ! -f "$SLM_FN" ]; then
  echo "❌ $SLM_FN not present"
  exit 1
fi

pass=0
fail=0
fail_msgs=()

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        want: '$want'")
    echo "  FAIL  $desc"
  fi
}

assert_contains() {
  local got="$1" needle="$2" desc="$3"
  if printf '%s' "$got" | grep -q -F -- "$needle"; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        needle: '$needle'")
    echo "  FAIL  $desc"
  fi
}

echo
echo "slm"
echo "───"

# 1. -h prints usage to stdout, exit 0.
out=$(fish --no-config -c "source '$SLM_FN'; slm -h" </dev/null 2>/dev/null); rc=$?
assert_eq "$rc" "0" "-h exits 0"
assert_contains "$out" "Usage:" "-h prints usage"

# 2. No prompt (empty args + empty stdin) -> usage on stderr, exit 2.
err=$(fish --no-config -c "source '$SLM_FN'; slm" </dev/null 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "no prompt exits 2"
assert_contains "$err" "Usage:" "no prompt prints usage to stderr"

# 3. Server down -> friendly message, exit 1. (</dev/null so the arg-only
#    call's stdin read gets EOF instead of blocking on an open pipe.)
err=$(SLM_URL=http://localhost:1/v1 fish --no-config -c "source '$SLM_FN'; slm hi" </dev/null 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "1" "server-down exits 1"
assert_contains "$err" "oMLX not reachable" "server-down reports oMLX unreachable"

# 4. Multi-line stdin where lines begin with `-` must not be misread as flags
#    to the internal `string join` calls. Regression for a bug where
#    `(string join \n $lines)` re-split on newlines through command
#    substitution, leaking `- bullet` fragments to the next join as flags.
#    Server-down is fine — we only assert the friendly-error path is reached
#    (not a `string join: -…: unknown option` fish crash).
err=$(SLM_URL=http://localhost:1/v1 fish --no-config -c "source '$SLM_FN'; slm" <<'EOF' 2>&1 >/dev/null
Title: foo

Description:
- bullet one
- bullet two
EOF
); rc=$?
assert_eq "$rc" "1" "leading-dash stdin doesn't crash slm"
assert_contains "$err" "oMLX not reachable" "leading-dash stdin still reaches friendly server-down error"
if printf '%s' "$err" | grep -q "string join:.*unknown option"; then
  fail=$((fail+1)); fail_msgs+=("FAIL  leading-dash stdin leaked to string join as a flag"); echo "  FAIL  leading-dash stdin no string-join flag leak"
else
  pass=$((pass+1)); echo "  PASS  leading-dash stdin no string-join flag leak"
fi

# 4. Live happy-path — only if oMLX is reachable and SLM_API_KEY is set (oMLX
#    needs the Bearer header; the probe + slm both inherit it from the env).
SLM_URL_DEFAULT="${SLM_URL:-http://localhost:8000/v1}"
if curl -sf -o /dev/null --max-time 2 -H "Authorization: Bearer ${SLM_API_KEY:-}" "$SLM_URL_DEFAULT/models" 2>/dev/null; then
  out=$(fish --no-config -c "source '$SLM_FN'; slm reply with only the word OK" </dev/null 2>/dev/null); rc=$?
  assert_eq "$rc" "0" "live: exits 0"
  if [ -n "$out" ]; then
    pass=$((pass+1)); echo "  PASS  live: non-empty completion"
  else
    fail=$((fail+1)); fail_msgs+=("FAIL  live: empty completion"); echo "  FAIL  live: non-empty completion"
  fi
else
  echo "  SKIP — oMLX not reachable at $SLM_URL_DEFAULT (or SLM_API_KEY unset), skipping live happy-path"
fi

echo
echo "─────────────────"
echo "passed: $pass"
echo "failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
