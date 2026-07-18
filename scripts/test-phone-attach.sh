#!/opt/homebrew/bin/bash
# Smoke tests for tmux-phone-attach (client-attached hook handler).
# Mock tmux logs every invocation and answers display-message from
# $CLIENT_INFO; mock ps serves a fixture process table; the sibling
# tmux-phone-twin is mocked to print $TWIN_OUT (or fail when empty).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0; fail=0; fail_msgs=()
check() {
  local name="$1"; shift
  if "$@"; then printf 'PASS  %s\n' "$name"; pass=$((pass+1))
  else printf 'FAIL  %s\n' "$name"; fail=$((fail+1)); fail_msgs+=("$name"); fi
}

# Build a sandbox: bin/ holds real tmux-phone-attach + _remote-ancestry
# and a MOCK tmux-phone-twin; shim/ holds mock tmux + ps.
build_sandbox() {
  local dir="$1" log="$2" table="$3"
  mkdir -p "$dir/bin" "$dir/shim"
  cp "$REPO/.config/tmux/bin/tmux-phone-attach" \
     "$REPO/.config/tmux/bin/_remote-ancestry" "$dir/bin/"

  cat > "$dir/bin/tmux-phone-twin" <<EOF
#!/opt/homebrew/bin/bash
echo "phone-twin \$*" >> "$log"
[ -n "\${TWIN_OUT:-}" ] || exit 1
printf '%s\n' "\$TWIN_OUT"
EOF
  chmod +x "$dir/bin/tmux-phone-twin"

  cat > "$dir/shim/tmux" <<EOF
#!/opt/homebrew/bin/bash
echo "\$*" >> "$log"
if [ "\$1" = display-message ]; then
  [ -n "\${CLIENT_INFO:-}" ] || exit 1
  printf '%s\n' "\$CLIENT_INFO"
fi
exit 0
EOF
  chmod +x "$dir/shim/tmux"

  cat > "$dir/shim/ps" <<EOF
#!/opt/homebrew/bin/bash
target=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -p) target="\$2"; shift 2 ;;
    -o) shift 2 ;;
    *)  shift ;;
  esac
done
[ -n "\$target" ] || exit 1
while IFS=' ' read -r pid ppid ucomm; do
  if [ "\$pid" = "\$target" ]; then
    printf '%s %s\n' "\$ppid" "\$ucomm"
    exit 0
  fi
done < "$table"
exit 1
EOF
  chmod +x "$dir/shim/ps"
}

REMOTE_TABLE='1001 900 tmux
900 800 fish
800 1 mosh-server'
LOCAL_TABLE='1001 900 tmux
900 800 fish
800 700 login
700 1 launchd'

# run_handler <dir> <log> [VAR=val ...]
run_handler() {
  local dir="$1" log="$2"; shift 2
  env "$@" PATH="$dir/shim:$PATH" "$dir/bin/tmux-phone-attach" /dev/ttys099
}

# Test 1: Ghostty termname -> no twin call, no switch, no source
test_ghostty_noop() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "$REMOTE_TABLE" > "$dir/table"
  build_sandbox "$dir" "$dir/log" "$dir/table"
  run_handler "$dir" "$dir/log" CLIENT_INFO="1001 xterm-ghostty notes" TWIN_OUT=notes-phone
  ! grep -q '^phone-twin' "$dir/log" || { echo "  twin called"; return 1; }
  ! grep -q 'switch-client' "$dir/log" || { echo "  switched"; return 1; }
  ! grep -q 'source-file' "$dir/log" || { echo "  sourced"; return 1; }
}
check "xterm-ghostty client -> no-op" test_ghostty_noop

# Test 2: local ancestry -> no-op even with non-ghostty TERM
test_local_noop() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "$LOCAL_TABLE" > "$dir/table"
  build_sandbox "$dir" "$dir/log" "$dir/table"
  run_handler "$dir" "$dir/log" CLIENT_INFO="1001 xterm-256color notes" TWIN_OUT=notes-phone
  ! grep -q '^phone-twin' "$dir/log" || { echo "  twin called"; return 1; }
  ! grep -q 'switch-client' "$dir/log" || { echo "  switched"; return 1; }
}
check "local ancestry -> no-op" test_local_noop

# Test 3: phone client -> twin, switch, destroy-unattached, repair
test_phone_full_path() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "$REMOTE_TABLE" > "$dir/table"
  build_sandbox "$dir" "$dir/log" "$dir/table"
  run_handler "$dir" "$dir/log" CLIENT_INFO="1001 xterm-256color notes" TWIN_OUT=notes-phone
  grep -Fxq 'phone-twin notes' "$dir/log" || { echo "  twin not called with notes"; return 1; }
  grep -Fq 'switch-client -c /dev/ttys099 -t =notes-phone' "$dir/log" \
    || { echo "  missing switch"; return 1; }
  grep -Fq 'set-option -t notes-phone destroy-unattached on' "$dir/log" \
    || { echo "  missing destroy-unattached"; return 1; }
  grep -q 'source-file' "$dir/log" || { echo "  missing repair source"; return 1; }
}
check "phone client -> twin + switch + destroy-unattached + repair" test_phone_full_path

# Test 4: target already a twin (twin==session) -> no switch, still repair
test_twin_target() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "$REMOTE_TABLE" > "$dir/table"
  build_sandbox "$dir" "$dir/log" "$dir/table"
  run_handler "$dir" "$dir/log" CLIENT_INFO="1001 xterm-256color notes-phone" TWIN_OUT=notes-phone
  ! grep -q 'switch-client' "$dir/log" || { echo "  switched into itself"; return 1; }
  grep -Fq 'set-option -t notes-phone destroy-unattached on' "$dir/log" \
    || { echo "  missing destroy-unattached"; return 1; }
  grep -q 'source-file' "$dir/log" || { echo "  missing repair source"; return 1; }
}
check "client attached to a twin -> no self-switch, still repairs" test_twin_target

# Test 5: twin script fails -> no switch, no repair, exit 0
test_twin_failure() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "$REMOTE_TABLE" > "$dir/table"
  build_sandbox "$dir" "$dir/log" "$dir/table"
  run_handler "$dir" "$dir/log" CLIENT_INFO="1001 xterm-256color notes" TWIN_OUT=
  ! grep -q 'switch-client' "$dir/log" || { echo "  switched"; return 1; }
  ! grep -q 'source-file' "$dir/log" || { echo "  sourced"; return 1; }
}
check "twin failure -> graceful no-op" test_twin_failure

# Test 6: display-message fails (client already gone) -> exit 0, silent
test_client_gone() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "$REMOTE_TABLE" > "$dir/table"
  build_sandbox "$dir" "$dir/log" "$dir/table"
  run_handler "$dir" "$dir/log" CLIENT_INFO= TWIN_OUT=notes-phone
  ! grep -q '^phone-twin' "$dir/log" || { echo "  twin called"; return 1; }
}
check "vanished client -> graceful no-op" test_client_gone

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'; for m in "${fail_msgs[@]}"; do printf '  - %s\n' "$m"; done
  exit 1
fi
