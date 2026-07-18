#!/opt/homebrew/bin/bash
# Smoke tests for tmux-ssh-indicator.
#
# Each test creates a tmpdir with mock `tmux` and `ps` binaries, prepends
# it to PATH, runs the script under test, and asserts the output. Mocks
# read fixture files (client list, ps table) prepared per-test.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO/.config/tmux/bin/tmux-ssh-indicator"

# Globe glyph as raw UTF-8 (U+F0AC, nf-fa-globe). Must match the helper.
GLYPH=$(printf '\xef\x82\xac')
EXPECT_SSH="$GLYPH "  # glyph + single space

pass=0
fail=0
fail_msgs=()

check() {
  local name="$1"; shift
  if "$@"; then
    printf 'PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$name"
    fail=$((fail + 1))
    fail_msgs+=("$name")
  fi
}

# Build mock tmux + ps in $1 (a tmpdir).
#   $2 = path to a file containing "pid session" client rows (may be empty)
#   $3 = path to a file containing "pid ppid comm" rows for `ps` to answer
# show-option answers the @phone_twin probe: sessions listed in the
# space-separated $TWIN_SESSIONS env var report 1, others empty.
build_shim() {
  local dir="$1" clients="$2" table="$3"

  cat > "$dir/tmux" <<EOF
#!/opt/homebrew/bin/bash
case "\$1" in
  list-clients) cat "$clients" ;;
  show-option)
    target=""
    while [ \$# -gt 0 ]; do
      case "\$1" in -t) target="\$2"; shift 2 ;; *) shift ;; esac
    done
    case " \${TWIN_SESSIONS:-} " in
      *" \${target#=} "*) echo 1 ;;
    esac
    ;;
esac
EOF
  chmod +x "$dir/tmux"

  cat > "$dir/ps" <<EOF
#!/opt/homebrew/bin/bash
# Minimal mock of \`ps -p <pid> -o ppid=,ucomm=\`.
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
  chmod +x "$dir/ps"
}

# Build a dual-field mock that distinguishes \`ps -o ucomm=\` (basename) from
# \`-o comm=\` (full argv-rendered string). Used by the macOS-quirk regression
# test below. Fixture rows are "pid ppid ucomm comm-rest..." — first three
# tokens are pid/ppid/ucomm, rest of the line is comm.
build_shim_dual_field() {
  local dir="$1" clients="$2" table="$3"

  cat > "$dir/tmux" <<EOF
#!/opt/homebrew/bin/bash
case "\$1" in
  list-clients) cat "$clients" ;;
  show-option)
    target=""
    while [ \$# -gt 0 ]; do
      case "\$1" in -t) target="\$2"; shift 2 ;; *) shift ;; esac
    done
    case " \${TWIN_SESSIONS:-} " in
      *" \${target#=} "*) echo 1 ;;
    esac
    ;;
esac
EOF
  chmod +x "$dir/tmux"

  cat > "$dir/ps" <<EOF
#!/opt/homebrew/bin/bash
target=""
flag=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -p) target="\$2"; shift 2 ;;
    -o) flag="\$2"; shift 2 ;;
    *)  shift ;;
  esac
done
[ -n "\$target" ] || exit 1
while IFS= read -r line; do
  [ -z "\$line" ] && continue
  read -r pid ppid ucomm comm <<<"\$line"
  if [ "\$pid" = "\$target" ]; then
    case "\$flag" in
      *ucomm*) printf '%s %s\n' "\$ppid" "\$ucomm" ;;
      *comm*)  printf '%s %s\n' "\$ppid" "\$comm" ;;
      *)       printf '%s %s\n' "\$ppid" "\$ucomm" ;;
    esac
    exit 0
  fi
done < "$table"
exit 1
EOF
  chmod +x "$dir/ps"
}

# ---------------------------------------------------------------------------
# Test 1: no attached clients -> empty output
# ---------------------------------------------------------------------------
test_no_clients() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  : > "$dir/clients"
  : > "$dir/table"
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ -z "$out" ] || { echo "  expected empty, got: $(printf %q "$out")"; return 1; }
}
check "no attached clients -> empty output" test_no_clients

# ---------------------------------------------------------------------------
# Test 2: one client whose ancestry includes sshd -> glyph + space
# ---------------------------------------------------------------------------
test_ssh_ancestor() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "1001 main" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
1001 900 tmux
900 800 zsh
800 700 sshd
700 1 launchd
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ "$out" = "$EXPECT_SSH" ] || { echo "  expected glyph+space, got: $(printf %q "$out")"; return 1; }
}
check "client ancestry through sshd -> glyph + space" test_ssh_ancestor

# ---------------------------------------------------------------------------
# Test 3: ancestry rooted in sshd-session (modern macOS naming) -> glyph
# ---------------------------------------------------------------------------
test_sshd_session_ancestor() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "2001 main" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
2001 1900 tmux
1900 1800 zsh
1800 1700 sshd-session
1700 1 launchd
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ "$out" = "$EXPECT_SSH" ] || { echo "  expected glyph+space, got: $(printf %q "$out")"; return 1; }
}
check "client ancestry through sshd-session -> glyph + space" test_sshd_session_ancestor

# ---------------------------------------------------------------------------
# Test 4: only-local ancestry -> empty
# ---------------------------------------------------------------------------
test_local_only() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "3001 main" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
3001 2900 tmux
2900 2800 zsh
2800 2700 login
2700 1 launchd
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ -z "$out" ] || { echo "  expected empty, got: $(printf %q "$out")"; return 1; }
}
check "local-only ancestry -> empty output" test_local_only

# ---------------------------------------------------------------------------
# Test 5: two clients, one local + one SSH -> glyph + space
# ---------------------------------------------------------------------------
test_mixed_clients() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n%s\n' "4001 main" "4002 work" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
4001 3900 tmux
3900 3800 zsh
3800 3700 login
3700 1 launchd
4002 3500 tmux
3500 3400 zsh
3400 3300 sshd
3300 1 launchd
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ "$out" = "$EXPECT_SSH" ] || { echo "  expected glyph+space, got: $(printf %q "$out")"; return 1; }
}
check "mixed local + SSH clients -> glyph + space" test_mixed_clients

# ---------------------------------------------------------------------------
# Test 6: macOS regression — sshd-session privsep child renders its argv
# string in `comm` (e.g. "sshd-session: martinciu@ttys008"), but `ucomm`
# returns the clean basename "sshd-session". Script must detect the SSH
# ancestry from `ucomm`. This case is what made the original PR ship a
# silent no-op on real machines — the prior tests all used clean comm
# strings the in-memory mock returned verbatim, missing the divergence.
# ---------------------------------------------------------------------------
test_macos_sshd_session_argv_rendering() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "5001 main" > "$dir/clients"
  # Fixture columns: pid ppid ucomm comm-rest...
  cat > "$dir/table" <<'EOF'
5001 4900 tmux tmux
4900 4800 zsh -zsh
4800 4700 sshd-session sshd-session: martinciu@ttys008
4700 1 sshd-session sshd-session: martinciu [priv]
EOF
  build_shim_dual_field "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ "$out" = "$EXPECT_SSH" ] || { echo "  expected glyph+space, got: $(printf %q "$out")"; return 1; }
}
check "macOS sshd-session: clean ucomm matches despite descriptive comm" test_macos_sshd_session_argv_rendering

# ---------------------------------------------------------------------------
# Test 7: ps cycle (ppid points back to seen pid) -> loop guard, empty
# ---------------------------------------------------------------------------
test_ps_cycle() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "6001 main" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
6001 6002 tmux
6002 6001 zsh
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ -z "$out" ] || { echo "  expected empty (loop guard), got: $(printf %q "$out")"; return 1; }
}
check "ps cycle (ppid loops back) -> loop guard, empty output" test_ps_cycle

# ---------------------------------------------------------------------------
# Test 8: ancestry rooted in mosh-server -> glyph. mosh-server daemonizes
# and re-parents to launchd, so it sits directly under pid 1 — this also
# regression-tests that the ucomm match fires before the ppid-0/1 stop.
# ---------------------------------------------------------------------------
test_mosh_server_ancestor() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "7001 main" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
7001 6900 tmux
6900 6800 fish
6800 1 mosh-server
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(PATH="$dir:$PATH" "$SCRIPT")
  [ "$out" = "$EXPECT_SSH" ] || { echo "  expected glyph+space, got: $(printf %q "$out")"; return 1; }
}
check "client ancestry through mosh-server -> glyph + space" test_mosh_server_ancestor

# ---------------------------------------------------------------------------
# Test 9: remote client but its session is a @phone_twin -> excluded, empty.
# The Mac-side globe means "a remote client OTHER than the phone is
# attached" (#366) — the phone in its bar-less twin must not light it.
# ---------------------------------------------------------------------------
test_phone_twin_excluded() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n' "8001 notes-phone" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
8001 7900 tmux
7900 7800 fish
7800 1 mosh-server
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(TWIN_SESSIONS="notes-phone" PATH="$dir:$PATH" "$SCRIPT")
  [ -z "$out" ] || { echo "  expected empty, got: $(printf %q "$out")"; return 1; }
}
check "remote client in @phone_twin session -> excluded, empty" test_phone_twin_excluded

# ---------------------------------------------------------------------------
# Test 10: phone twin + a genuine SSH client -> glyph (exclusion is
# per-client, not a kill switch).
# ---------------------------------------------------------------------------
test_phone_twin_plus_ssh() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  printf '%s\n%s\n' "8001 notes-phone" "8101 main" > "$dir/clients"
  cat > "$dir/table" <<'EOF'
8001 7900 tmux
7900 7800 fish
7800 1 mosh-server
8101 8000 tmux
8000 7700 zsh
7700 7600 sshd
7600 1 launchd
EOF
  build_shim "$dir" "$dir/clients" "$dir/table"
  local out
  out=$(TWIN_SESSIONS="notes-phone" PATH="$dir:$PATH" "$SCRIPT")
  [ "$out" = "$EXPECT_SSH" ] || { echo "  expected glyph+space, got: $(printf %q "$out")"; return 1; }
}
check "phone twin + genuine SSH client -> glyph + space" test_phone_twin_plus_ssh

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'
  for msg in "${fail_msgs[@]}"; do printf '  - %s\n' "$msg"; done
  exit 1
fi
