#!/opt/homebrew/bin/bash
# Smoke tests for tmux-pr-detect and tmux-status-right.
#
# Strategy: run the helpers with HOME pointed at a throwaway dir and PATH
# rewritten so a stub `gh` shim wins over the real one. The shim writes
# its invocation to a counter file so we can assert "second call within
# TTL doesn't re-invoke gh".
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECT="$REPO/.config/tmux/bin/tmux-pr-detect"
ORCHESTRATOR="$REPO/.config/tmux/bin/tmux-status-right"

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
    fail_msgs+=("FAIL  $desc"$'\n'"        got: '$got'"$'\n'"        unwanted: '$needle'")
    echo "  FAIL  $desc"
  else
    pass=$((pass+1))
    echo "  PASS  $desc"
  fi
}

# Build a sandbox: TEST_HOME for $HOME, plus a bin/ holding our gh shim.
setup_sandbox() {
  local fixture="$1" gh_response="$2"
  TEST_HOME=$(mktemp -d)
  mkdir -p "$TEST_HOME/bin"
  GH_CALLS="$TEST_HOME/gh-calls"
  : > "$GH_CALLS"

  cat > "$TEST_HOME/bin/gh" <<EOF
#!/opt/homebrew/bin/bash
# Test shim. Records each invocation; emits the same output that real
# gh would produce after applying its server-side --jq filter
# 'select(.state == "OPEN" or .state == "DRAFT") | .number' to a
# {"state":"...","number":N} payload.
echo "\$@" >> "$GH_CALLS"
case "$gh_response" in
  open)   printf '%s\n' '105' ;;
  draft)  printf '%s\n' '106' ;;
  closed) ;;  # state filter rejects → empty stdout
  none)   exit 1 ;;
esac
EOF
  chmod +x "$TEST_HOME/bin/gh"

  # XDG_CACHE_HOME under TEST_HOME so cache files are isolated.
  export XDG_CACHE_HOME="$TEST_HOME/cache"
  export HOME="$TEST_HOME"
  export PATH="$TEST_HOME/bin:$PATH"
}

teardown_sandbox() {
  rm -rf "$TEST_HOME"
  PATH="${PATH#$TEST_HOME/bin:}"
  export PATH
  unset TEST_HOME GH_CALLS XDG_CACHE_HOME
}

# Wait for a backgrounded refresh to finish writing its cache file.
# tmux-pr-detect forks the gh shim into the background; without this wait,
# follow-up assertions can race the file-write.
wait_for_cache() {
  local cache_dir="$1"
  local i=0
  while [ "$i" -lt 50 ]; do
    if [ -n "$(ls "$cache_dir" 2>/dev/null)" ]; then
      # Also wait for any tmp swap to finish (rename is atomic but the
      # background subshell exit may lag the rename slightly).
      sleep 0.05
      return 0
    fi
    sleep 0.02
    i=$((i+1))
  done
  return 1
}

count_gh_calls() {
  wc -l < "$GH_CALLS" | tr -d ' '
}

echo
echo "tmux-pr-detect"
echo "──────────────"

if [ ! -x "$DETECT" ]; then
  echo "  SKIP — $DETECT not present yet"
else
  # Test 1: non-git dir → empty output, gh never invoked.
  setup_sandbox "" open
  not_repo=$(mktemp -d)
  out=$("$DETECT" "$not_repo")
  assert_eq "$out" "" "non-git dir -> empty output"
  assert_eq "$(count_gh_calls)" "0" "non-git dir -> gh not invoked"
  rm -rf "$not_repo"
  teardown_sandbox

  # Test 2: git dir + gh OPEN → empty on cold call, then number after refresh.
  setup_sandbox "" open
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q -b feat/x && \
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  out=$("$DETECT" "$fixture")
  assert_eq "$out" "" "cold call -> empty (cache miss, refresh forked)"
  wait_for_cache "$XDG_CACHE_HOME/tmux-pr-pin" || \
    echo "  WARN  cache file did not appear within timeout"
  out=$("$DETECT" "$fixture")
  assert_eq "$out" "105" "after refresh -> cached PR number"
  # Second call within TTL must not invoke gh again.
  calls_before=$(count_gh_calls)
  out=$("$DETECT" "$fixture")
  calls_after=$(count_gh_calls)
  assert_eq "$out" "105" "second call within TTL returns cached value"
  assert_eq "$calls_before" "$calls_after" "second call within TTL does not invoke gh"
  rm -rf "$fixture"
  teardown_sandbox

  # Test 3: gh DRAFT → number returned (drafts treated identically to open).
  setup_sandbox "" draft
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q -b feat/y && \
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  "$DETECT" "$fixture" >/dev/null
  wait_for_cache "$XDG_CACHE_HOME/tmux-pr-pin" || true
  out=$("$DETECT" "$fixture")
  assert_eq "$out" "106" "draft PR -> number returned"
  rm -rf "$fixture"
  teardown_sandbox

  # Test 4: gh CLOSED → empty (state filter rejects it).
  setup_sandbox "" closed
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q -b feat/z && \
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  "$DETECT" "$fixture" >/dev/null
  wait_for_cache "$XDG_CACHE_HOME/tmux-pr-pin" || true
  out=$("$DETECT" "$fixture")
  assert_eq "$out" "" "closed PR -> empty"
  rm -rf "$fixture"
  teardown_sandbox

  # Test 5: gh exits non-zero (no PR for branch) → empty.
  setup_sandbox "" none
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q -b feat/no-pr && \
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  "$DETECT" "$fixture" >/dev/null
  wait_for_cache "$XDG_CACHE_HOME/tmux-pr-pin" || true
  out=$("$DETECT" "$fixture")
  assert_eq "$out" "" "no PR for branch -> empty"
  rm -rf "$fixture"
  teardown_sandbox
fi

echo
echo "tmux-status-right"
echo "─────────────────"

if [ ! -x "$ORCHESTRATOR" ]; then
  echo "  SKIP — $ORCHESTRATOR not present yet"
else
  # Test 6: no PR → output omits tri_r (flush-right git chip).
  setup_sandbox "" none
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q -b main && \
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  "$ORCHESTRATOR" "$fixture" >/dev/null  # warm cache
  wait_for_cache "$XDG_CACHE_HOME/tmux-pr-pin" || true
  out=$("$ORCHESTRATOR" "$fixture")
  assert_not_contains "$out" $'\xee\x82\xb4' "no-PR path: tri_r absent (flush-right)"
  assert_contains "$out" "main" "no-PR path: shows branch"
  assert_not_contains "$out" "#cb4b16" "no-PR path: orange not in output"
  rm -rf "$fixture"
  teardown_sandbox

  # Test 7: with PR → orange chip body precedes the git chip; tri_r still absent.
  setup_sandbox "" open
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q -b feat/x && \
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  "$ORCHESTRATOR" "$fixture" >/dev/null  # warm cache
  wait_for_cache "$XDG_CACHE_HOME/tmux-pr-pin" || true
  out=$("$ORCHESTRATOR" "$fixture")
  assert_contains "$out" "#cb4b16" "with-PR path: orange in output"
  assert_contains "$out" "#105" "with-PR path: PR number rendered"
  assert_contains "$out" $'\xef\x90\x87' "with-PR path: PR glyph U+F407 in output"
  assert_not_contains "$out" $'\xee\x82\xb4' "with-PR path: tri_r still absent (git flush-right)"
  # Order check: orange chip body must appear before the git chip body.
  # The fixture is a plain main checkout, so the git chip uses violet (#6c71c4).
  orange_pos=$(printf '%s' "$out" | grep -b -o "#cb4b16" | head -1 | cut -d: -f1)
  git_pos=$(printf '%s' "$out" | grep -b -o "#6c71c4" | head -1 | cut -d: -f1)
  if [ -n "$orange_pos" ] && [ -n "$git_pos" ] && [ "$orange_pos" -lt "$git_pos" ]; then
    pass=$((pass+1))
    echo "  PASS  with-PR path: orange chip emitted before git chip"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  with-PR path: orange chip should precede git chip"$'\n'"        orange_pos=$orange_pos git_pos=$git_pos")
    echo "  FAIL  with-PR path: orange chip should precede git chip"
  fi
  rm -rf "$fixture"
  teardown_sandbox
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "──────"
  printf '%s\n\n' "${fail_msgs[@]}"
  echo "$pass passed, $fail failed"
  exit 1
fi
echo "$pass passed, $fail failed"
