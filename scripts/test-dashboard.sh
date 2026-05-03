#!/usr/bin/env bash
# Smoke + integration tests for bin/dashboard.
# Invoked from scripts/test-helpers.sh; can also be run standalone.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DASH="$REPO/bin/dashboard"

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

echo
echo "bin/dashboard"
echo "─────────────"

if [ ! -x "$DASH" ]; then
  echo "  SKIP — $DASH not present yet"
else
  # ── arg parsing: 0 args -> usage on stderr, exit 1 ──
  out=$("$DASH" 2>&1); rc=$?
  assert_eq "$rc" "1" "0 args -> exit 1"
  assert_contains "$out" "Usage:" "0 args -> usage on stderr"

  # ── arg parsing: --cols requires a numeric value ──
  out=$("$DASH" '*-test' --cols 2>&1); rc=$?
  assert_eq "$rc" "1" "--cols without value -> exit 1"
  assert_contains "$out" "--cols requires" "--cols without value -> error message"

  out=$("$DASH" '*-test' --cols abc 2>&1); rc=$?
  assert_eq "$rc" "1" "--cols non-numeric -> exit 1"
  assert_contains "$out" "--cols requires" "--cols non-numeric -> error message"

  # ── derived_name: pattern -> session-name suffix ──
  out=$(DASHBOARD_TEST_DERIVED='*-agent' "$DASH" --print-derived 2>&1)
  assert_eq "$out" "agent" "'*-agent' -> derived 'agent'"

  out=$(DASHBOARD_TEST_DERIVED='claude-*-prod' "$DASH" --print-derived 2>&1)
  assert_eq "$out" "claudeprod" "'claude-*-prod' -> derived 'claudeprod'"

  out=$(DASHBOARD_TEST_DERIVED='build-*' "$DASH" --print-derived 2>&1)
  assert_eq "$out" "build" "'build-*' -> derived 'build'"

  # ── derived_name: empty result -> error ──
  out=$(DASHBOARD_TEST_DERIVED='***' "$DASH" --print-derived 2>&1); rc=$?
  assert_eq "$rc" "1" "all-special pattern -> exit 1"
  assert_contains "$out" "empty derived name" "all-special pattern -> error message"

  # ── discover_sessions: filter + dashboard:* exclusion ──
  shimdir=$(mktemp -d)
  cat >"$shimdir/tmux" <<'SHIM'
#!/usr/bin/env bash
# Shim: tmux list-sessions -F '#{session_last_attached} #{session_name}'
case "$*" in
  "list-sessions -F #{session_last_attached} #{session_name}")
    cat <<-EOF
		3000 dashboard-agent
		2500 claude-prod
		2000 build-1
		1500 build-2
		1000 claude-staging
	EOF
    ;;
  *) echo "tmux shim: unsupported: $*" >&2; exit 99 ;;
esac
SHIM
  chmod +x "$shimdir/tmux"

  # Match 'build-*' -> build-1, build-2 (most-recently-attached first)
  out=$(PATH="$shimdir:$PATH" "$DASH" --print-discover 'build-*' 2>&1)
  expected=$'build-1\nbuild-2'
  assert_eq "$out" "$expected" "'build-*' matches build-1, build-2 (mru order)"

  # Match 'claude-*' -> claude-prod, claude-staging
  out=$(PATH="$shimdir:$PATH" "$DASH" --print-discover 'claude-*' 2>&1)
  expected=$'claude-prod\nclaude-staging'
  assert_eq "$out" "$expected" "'claude-*' matches claude-prod, claude-staging"

  # Match '*' -> excludes dashboard-agent
  out=$(PATH="$shimdir:$PATH" "$DASH" --print-discover '*' 2>&1)
  if printf '%s' "$out" | grep -qx 'dashboard-agent'; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  '*' must exclude dashboard-agent"$'\n'"        got: '$out'")
    echo "  FAIL  '*' must exclude dashboard-agent"
  else
    pass=$((pass+1))
    echo "  PASS  '*' excludes dashboard-agent"
  fi

  # No match -> empty stdout, exit 0
  out=$(PATH="$shimdir:$PATH" "$DASH" --print-discover 'no-such-*' 2>&1); rc=$?
  assert_eq "$rc" "0" "no match -> exit 0"
  assert_eq "$out" "" "no match -> empty stdout"

  rm -rf "$shimdir"

  # ── Integration tests against an isolated tmux server ──
  # Use TMUX_SOCKET=dash-test so the dashboard script's `tmx` helper passes
  # `-L dash-test` to every tmux invocation.
  TMUX_SOCKET=dash-test
  export TMUX_SOCKET

  # Helper: ensure clean test server before each integration block.
  reset_test_tmux() {
    tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
    tmux -L "$TMUX_SOCKET" start-server
  }

  # Helper: count panes in a window of a session on the test server.
  pane_count() {
    tmux -L "$TMUX_SOCKET" list-panes -t "$1" 2>/dev/null | wc -l | tr -d ' '
  }

  # Helper: tear down the test server after assertions in a block.
  teardown_test_tmux() {
    tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
  }

  # ── build_dashboard: 2 matching sessions -> 2 tiles ──
  # Session names end in '-agent' so the '*-agent' glob actually matches.
  reset_test_tmux
  tmux -L "$TMUX_SOCKET" new-session -d -s 1-agent 'sleep 999'
  tmux -L "$TMUX_SOCKET" new-session -d -s 2-agent 'sleep 999'
  tmux -L "$TMUX_SOCKET" new-session -d -s test-build-1 'sleep 999'

  out=$("$DASH" '*-agent' 2>&1); rc=$?
  assert_eq "$rc" "0" "dashboard '*-agent' exits 0"
  if tmux -L "$TMUX_SOCKET" has-session -t dashboard-agent 2>/dev/null; then
    pass=$((pass+1)); echo "  PASS  dashboard-agent session created"
  else
    fail=$((fail+1)); fail_msgs+=("FAIL  dashboard-agent session not created")
    echo "  FAIL  dashboard-agent session not created"
  fi
  assert_eq "$(pane_count dashboard-agent)" "2" "dashboard-agent has 2 tiles for *-agent matches"

  # ── Idempotent rebuild: re-run with same pattern, kill one source, expect 1 tile ──
  tmux -L "$TMUX_SOCKET" kill-session -t 2-agent 2>/dev/null || true
  out=$("$DASH" '*-agent' 2>&1); rc=$?
  assert_eq "$rc" "0" "rebuild after source kill exits 0"
  assert_eq "$(pane_count dashboard-agent)" "1" "rebuild drops vanished session's tile"

  # ── Pane border titles == source session names ──
  reset_test_tmux
  tmux -L "$TMUX_SOCKET" new-session -d -s 1-agent 'sleep 999'
  tmux -L "$TMUX_SOCKET" new-session -d -s 2-agent 'sleep 999'
  "$DASH" '*-agent' >/dev/null 2>&1

  titles=$(tmux -L "$TMUX_SOCKET" list-panes -t dashboard-agent -F '#{pane_title}' | sort)
  expected=$(printf '%s\n' 1-agent 2-agent | sort)
  assert_eq "$titles" "$expected" "pane titles match source session names"

  status=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-agent -v pane-border-status 2>/dev/null)
  assert_eq "$status" "top" "pane-border-status set to 'top' on dashboard session"

  # ── --cols N: explicit grid shape ──
  reset_test_tmux
  for n in 1 2 3 4 5 6; do
    tmux -L "$TMUX_SOCKET" new-session -d -s "test-grid-$n" 'sleep 999'
  done

  # --cols 1 -> all 6 in a single column (6 rows)
  "$DASH" '*-grid-*' --cols 1 >/dev/null 2>&1
  cols_seen=$(tmux -L "$TMUX_SOCKET" list-panes -t dashboard-grid -F '#{pane_left}' | sort -u | wc -l | tr -d ' ')
  assert_eq "$cols_seen" "1" "--cols 1 produces a single column"

  # --cols 2 -> 2 columns, 3 rows
  "$DASH" '*-grid-*' --cols 2 >/dev/null 2>&1
  cols_seen=$(tmux -L "$TMUX_SOCKET" list-panes -t dashboard-grid -F '#{pane_left}' | sort -u | wc -l | tr -d ' ')
  rows_seen=$(tmux -L "$TMUX_SOCKET" list-panes -t dashboard-grid -F '#{pane_top}' | sort -u | wc -l | tr -d ' ')
  assert_eq "$cols_seen" "2" "--cols 2 produces 2 distinct columns"
  assert_eq "$rows_seen" "3" "--cols 2 with 6 sources produces 3 rows"

  # ── State stored on dashboard session ──
  pat=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-grid -v @dashboard-pattern 2>/dev/null)
  assert_eq "$pat" "*-grid-*" "@dashboard-pattern stored on dashboard session"

  c=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-grid -v @dashboard-cols 2>/dev/null)
  assert_eq "$c" "2" "@dashboard-cols stored on dashboard session"

  p=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-grid -v @dashboard-page 2>/dev/null)
  assert_eq "$p" "0" "@dashboard-page initialized to 0"

  pages=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-grid -v @dashboard-pages 2>/dev/null)
  if printf '%s' "$pages" | grep -qE '^[1-9][0-9]*$'; then
    pass=$((pass+1)); echo "  PASS  @dashboard-pages is a positive integer ($pages)"
  else
    fail=$((fail+1)); fail_msgs+=("FAIL  @dashboard-pages should be positive int; got '$pages'")
    echo "  FAIL  @dashboard-pages should be positive int; got '$pages'"
  fi

  status_r=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-grid -v status-right 2>/dev/null)
  assert_contains "$status_r" "dashboard-grid" "status-right shows session name"
  assert_contains "$status_r" "/" "status-right shows page indicator"

  # ── Pagination ──
  reset_test_tmux
  for n in 1 2 3 4 5 6; do
    tmux -L "$TMUX_SOCKET" new-session -d -s "test-pg-$n" 'sleep 999'
  done
  "$DASH" '*-pg-*' --cols 1 >/dev/null 2>&1

  # tmux key bindings will pass DASHBOARD_TARGET=#{session_name} so the script
  # knows which session triggered the call (mirrors what Task 13 wires up).
  page_down_via_run_shell() {
    tmux -L "$TMUX_SOCKET" run-shell -t "$1" \
      "TMUX_SOCKET=$TMUX_SOCKET DASHBOARD_TARGET=$1 $DASH --page-down"
  }
  page_up_via_run_shell() {
    tmux -L "$TMUX_SOCKET" run-shell -t "$1" \
      "TMUX_SOCKET=$TMUX_SOCKET DASHBOARD_TARGET=$1 $DASH --page-up"
  }

  page_down_via_run_shell dashboard-pg
  p=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-pg -v @dashboard-page 2>/dev/null)
  assert_eq "$p" "1" "--page-down advances @dashboard-page from 0 to 1"

  page_down_via_run_shell dashboard-pg
  p=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-pg -v @dashboard-page 2>/dev/null)
  assert_eq "$p" "1" "--page-down clamps at last page"

  page_up_via_run_shell dashboard-pg
  p=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-pg -v @dashboard-page 2>/dev/null)
  assert_eq "$p" "0" "--page-up returns to first page"

  page_up_via_run_shell dashboard-pg
  p=$(tmux -L "$TMUX_SOCKET" show-options -t dashboard-pg -v @dashboard-page 2>/dev/null)
  assert_eq "$p" "0" "--page-up clamps at 0"

  # ── --page-down outside dashboard:* bails silently ──
  out=$("$DASH" --page-down 2>&1); rc=$?
  assert_eq "$rc" "0" "--page-down outside dashboard exits 0 (silent bail)"

  # ── --rebuild reads stored pattern and refreshes ──
  reset_test_tmux
  tmux -L "$TMUX_SOCKET" new-session -d -s test-reb-1 'sleep 999'
  tmux -L "$TMUX_SOCKET" new-session -d -s test-reb-2 'sleep 999'
  "$DASH" '*-reb-*' --cols 1 >/dev/null 2>&1

  # Spawn a third source after dashboard exists; --rebuild should pick it up.
  tmux -L "$TMUX_SOCKET" new-session -d -s test-reb-3 'sleep 999'
  tmux -L "$TMUX_SOCKET" run-shell -t dashboard-reb \
    "TMUX_SOCKET=$TMUX_SOCKET DASHBOARD_TARGET=dashboard-reb $DASH --rebuild"
  count=$(pane_count dashboard-reb)
  assert_eq "$count" "3" "--rebuild adds tile for newly-spawned source"

  # ── --rebuild outside dashboard bails silently ──
  out=$("$DASH" --rebuild 2>&1); rc=$?
  assert_eq "$rc" "0" "--rebuild outside dashboard exits 0 (silent bail)"

  teardown_test_tmux
  unset TMUX_SOCKET
fi

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "test-dashboard.sh passed: $pass"
echo "test-dashboard.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
