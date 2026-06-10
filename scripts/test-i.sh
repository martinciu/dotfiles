#!/opt/homebrew/bin/bash
# Smoke tests for bin/i — the closed-bead guard in particular.
# Invoked from scripts/test-helpers.sh; can also be run standalone.
#
# Harness: real `bd` against a scratch .beads per fixture; gh / sesh / s are
# PATH shims (pattern from test-s.sh). The slug is always passed explicitly
# so the slm pipeline is never invoked — these tests stay deterministic and
# offline.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
I="$REPO/bin/i"

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
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        unwanted: '$needle'")
    echo "  FAIL  $desc"
  else
    pass=$((pass+1))
    echo "  PASS  $desc"
  fi
}

echo
echo "bin/i"
echo "─────"

if [ ! -x "$I" ]; then
  echo "  SKIP — $I not present yet"
elif ! command -v bd >/dev/null 2>&1; then
  echo "  SKIP — bd not installed"
else
  # ─── fixture + shim helpers ────────────────
  # A fixture is a temp git repo with its own scratch .beads (prefix t-, so
  # issue 7 → bead t-7). Shims shadow gh / sesh / s on PATH; bd, jq, git
  # stay real.
  make_fixture() {
    local fx
    fx=$(mktemp -d)
    ( cd "$fx" && git init -q . && bd init --stealth --prefix t- >/dev/null 2>&1 )
    # Physical path (resolves macOS /var -> /private/var) to match what
    # bin/i computes via git rev-parse --path-format=absolute + pwd -P.
    cd "$fx" && pwd -P
  }

  write_shims() {
    # $1 = shimdir, $2 = fixture real path (sesh must map it to a project)
    local d="$1" fx="$2"
    cat >"$d/gh" <<SHIM
#!/opt/homebrew/bin/bash
echo "\$@" >>"$d/gh.log"
printf '{"title":"Test issue seven","body":"Test body","url":"https://github.com/x/y/issues/7"}\n'
SHIM
    cat >"$d/sesh" <<SHIM
#!/opt/homebrew/bin/bash
printf '[{"Name":"fixproject","Path":"%s"}]\n' '$fx'
SHIM
    cat >"$d/s" <<SHIM
#!/opt/homebrew/bin/bash
echo "\$@" >>"$d/s.log"
echo "S_CLAUDE_CMD=\${S_CLAUDE_CMD:-}" >>"$d/s.log"
exit 0
SHIM
    chmod +x "$d/gh" "$d/sesh" "$d/s"
  }

  bead_status() { ( cd "$1" && bd show t-7 --json 2>/dev/null | jq -r '.[0].status // empty' ); }
  bead_json()   { ( cd "$1" && bd show t-7 --json 2>/dev/null ); }

  # ─── non-numeric issue arg -> usage error ──────────────────────────
  out=$("$I" notanumber 2>&1); rc=$?
  assert_eq "$rc" "1" "non-numeric issue -> exit 1"
  assert_contains "$out" "issue must be a number" "non-numeric issue -> error message"

  # ─── fresh issue: bead created, s exec'd with project + branch ─────
  fx=$(make_fixture); shimdir=$(mktemp -d); write_shims "$shimdir" "$fx"
  out=$( cd "$fx" && env PATH="$shimdir:$PATH" "$I" 7 myslug 2>&1 ); rc=$?
  assert_eq "$rc" "0" "fresh issue -> exit 0"
  assert_eq "$(bead_status "$fx")" "open" "fresh issue -> bead t-7 created open"
  assert_contains "$(bead_json "$fx")" "branch:7-myslug" "fresh issue -> branch label added"
  assert_contains "$(cat "$shimdir/s.log")" "fixproject 7-myslug" "fresh issue -> s called with project + branch"
  assert_contains "$(cat "$shimdir/s.log")" "/mc:brainstorm" "fresh issue -> s seeded with /mc:brainstorm"

  # ─── re-run on an OPEN bead: adopt silently, no prompt ─────────────
  out=$( cd "$fx" && env PATH="$shimdir:$PATH" "$I" 7 otherslug 2>&1 ); rc=$?
  assert_eq "$rc" "0" "open-bead re-run -> exit 0"
  assert_not_contains "$out" "closed" "open-bead re-run -> no closed-bead prompt"
  assert_contains "$(cat "$shimdir/s.log")" "fixproject 7-otherslug" "open-bead re-run -> s called with new branch"
  rm -rf "$shimdir" "$fx"

  # ─── closed bead + d: delete & recreate fresh ──────────────────────
  fx=$(make_fixture); shimdir=$(mktemp -d); write_shims "$shimdir" "$fx"
  ( cd "$fx" && env PATH="$shimdir:$PATH" "$I" 7 first >/dev/null 2>&1 )
  ( cd "$fx" && bd comment t-7 "plan: .superpowers/plans/old.md" >/dev/null 2>&1 \
             && bd update t-7 --description "distilled summary of discarded spec" >/dev/null 2>&1 \
             && bd close t-7 >/dev/null 2>&1 )
  out=$( cd "$fx" && printf 'd\n' | env PATH="$shimdir:$PATH" "$I" 7 fresh 2>&1 ); rc=$?
  assert_eq "$rc" "0" "closed+d -> exit 0"
  assert_contains "$out" "recreated" "closed+d -> announces recreate"
  assert_eq "$(bead_status "$fx")" "open" "closed+d -> bead is open again"
  json=$(bead_json "$fx")
  assert_contains "$json" "Test body" "closed+d -> description refreshed from the live issue"
  assert_not_contains "$json" "distilled summary" "closed+d -> stale description gone"
  assert_not_contains "$json" "plan: .superpowers/plans/old.md" "closed+d -> stale plan comment gone"
  assert_not_contains "$json" "branch:7-first" "closed+d -> stale branch label gone"
  assert_contains "$json" "branch:7-fresh" "closed+d -> new branch label present"
  assert_contains "$(cat "$shimdir/s.log")" "fixproject 7-fresh" "closed+d -> s called with new branch"
  rm -rf "$shimdir" "$fx"

  # ─── closed bead + r: reopen & adopt, history kept ─────────────────
  fx=$(make_fixture); shimdir=$(mktemp -d); write_shims "$shimdir" "$fx"
  ( cd "$fx" && env PATH="$shimdir:$PATH" "$I" 7 first >/dev/null 2>&1 )
  ( cd "$fx" && bd update t-7 --description "distilled summary of prior spec" >/dev/null 2>&1 \
             && bd close t-7 >/dev/null 2>&1 )
  out=$( cd "$fx" && printf 'r\n' | env PATH="$shimdir:$PATH" "$I" 7 again 2>&1 ); rc=$?
  assert_eq "$rc" "0" "closed+r -> exit 0"
  assert_contains "$out" "reopened" "closed+r -> announces reopen"
  assert_eq "$(bead_status "$fx")" "open" "closed+r -> bead is open again"
  json=$(bead_json "$fx")
  assert_contains "$json" "distilled summary of prior spec" "closed+r -> prior description kept"
  assert_contains "$json" "branch:7-first" "closed+r -> prior branch label kept"
  assert_contains "$json" "branch:7-again" "closed+r -> new branch label added"
  rm -rf "$shimdir" "$fx"

  # ─── closed bead + abort (explicit 'a' and EOF) ────────────────────
  fx=$(make_fixture); shimdir=$(mktemp -d); write_shims "$shimdir" "$fx"
  ( cd "$fx" && env PATH="$shimdir:$PATH" "$I" 7 first >/dev/null 2>&1 )
  ( cd "$fx" && bd close t-7 >/dev/null 2>&1 )
  : >"$shimdir/s.log"
  out=$( cd "$fx" && printf 'a\n' | env PATH="$shimdir:$PATH" "$I" 7 fresh 2>&1 ); rc=$?
  assert_eq "$rc" "1" "closed+a -> exit 1"
  assert_contains "$out" "aborted" "closed+a -> abort message"
  assert_eq "$(bead_status "$fx")" "closed" "closed+a -> bead left closed"
  out=$( cd "$fx" && printf '' | env PATH="$shimdir:$PATH" "$I" 7 fresh 2>&1 ); rc=$?
  assert_eq "$rc" "1" "closed+EOF -> exit 1 (non-interactive fails safe)"
  assert_eq "$(bead_status "$fx")" "closed" "closed+EOF -> bead left closed"
  assert_not_contains "$(cat "$shimdir/s.log")" "7-fresh" "abort paths never reach s"
  rm -rf "$shimdir" "$fx"
fi

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "test-i.sh passed: $pass"
echo "test-i.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
