#!/opt/homebrew/bin/bash
# Smoke tests for tmux-statusbar-guard (#372 belt-and-braces self-heal).
# A mock tmux logs invocations and answers `show-options -gv status-right`
# from $STATUS_RIGHT; the guard sources the real _statusbar-clobbered.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0; fail=0; fail_msgs=()
check() {
  local name="$1"; shift
  if "$@"; then printf 'PASS  %s\n' "$name"; pass=$((pass+1))
  else printf 'FAIL  %s\n' "$name"; fail=$((fail+1)); fail_msgs+=("$name"); fi
}

build_sandbox() {
  local dir="$1" log="$2"
  mkdir -p "$dir/bin" "$dir/shim"
  cp "$REPO/.config/tmux/bin/tmux-statusbar-guard" \
     "$REPO/.config/tmux/bin/_statusbar-clobbered" "$dir/bin/"
  cat > "$dir/shim/tmux" <<EOF
#!/opt/homebrew/bin/bash
echo "\$*" >> "$log"
if [ "\$1" = show-options ]; then printf '%s\n' "\${STATUS_RIGHT:-}"; fi
[ -n "\${TMUX_FAIL:-}" ] && exit 1
exit 0
EOF
  chmod +x "$dir/shim/tmux"
}

run_guard() {
  local dir="$1" log="$2"; shift 2
  env "$@" PATH="$dir/shim:$PATH" "$dir/bin/tmux-statusbar-guard"
}

# Test 1: clobbered (empty status-right) -> re-sources, prints nothing
test_clobbered_repairs() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_sandbox "$dir" "$dir/log"
  local out; out=$(run_guard "$dir" "$dir/log" STATUS_RIGHT="")
  [ -z "$out" ] || { echo "  printed: $out"; return 1; }
  grep -q 'source-file' "$dir/log" || { echo "  no source-file"; return 1; }
}
check "empty status-right -> re-source, no output" test_clobbered_repairs

# Test 2: healthy status-right -> no re-source, prints nothing
test_healthy_noop() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_sandbox "$dir" "$dir/log"
  local out; out=$(run_guard "$dir" "$dir/log" STATUS_RIGHT="#(tmux-status-right)")
  [ -z "$out" ] || { echo "  printed: $out"; return 1; }
  ! grep -q 'source-file' "$dir/log" || { echo "  sourced when healthy"; return 1; }
}
check "populated status-right -> no source-file" test_healthy_noop

# Test 3: tmux failing -> guard still exits 0
test_tmux_failure_exit0() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_sandbox "$dir" "$dir/log"
  local rc=0
  run_guard "$dir" "$dir/log" TMUX_FAIL=1 STATUS_RIGHT="" >/dev/null || rc=$?
  [ "$rc" -eq 0 ] || { echo "  exited $rc"; return 1; }
}
check "tmux failure -> exit 0" test_tmux_failure_exit0

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'; for m in "${fail_msgs[@]}"; do printf '  - %s\n' "$m"; done
  exit 1
fi
