#!/opt/homebrew/bin/bash
# Smoke tests for conf.d/50-moshi-tmux.fish (Moshi -> bar-less grouped twin).
#
# Each test builds a tmpdir with a mock `tmux` that logs every invocation
# ("$*" per line) and answers has-session / display-message from env-var
# fixtures (HAS_NOTES / HAS_PHONE exit codes, PHONE_GROUP group name).
# The snippet is sourced under `fish --no-config -i -c` so its
# `status is-interactive` gate passes; `env -u TMUX` clears the outer tmux.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPET="$REPO/.config/fish/conf.d/50-moshi-tmux.fish"

ATTACH_LINE='new-session -A -s phone -t notes ; set status off ; set destroy-unattached on'

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

# Build the mock tmux in $1 (a tmpdir); it appends "$*" to $2 on every call.
build_shim() {
  local dir="$1" log="$2"

  cat > "$dir/tmux" <<EOF
#!/opt/homebrew/bin/bash
echo "\$*" >> "$log"
case "\$1" in
  has-session)
    case "\$*" in
      *"-t notes"*) exit "\${HAS_NOTES:-1}" ;;
      *"-t phone"*) exit "\${HAS_PHONE:-1}" ;;
    esac
    ;;
  display-message)
    printf '%s\n' "\${PHONE_GROUP:-phone}"
    ;;
esac
exit 0
EOF
  chmod +x "$dir/tmux"
}

# run_snippet <dir> <log> [VAR=val ...] — source the snippet with the shim
# first on PATH and the given env fixtures. TMUX is cleared unless a fixture
# re-sets it.
run_snippet() {
  local dir="$1" log="$2"; shift 2
  env -u TMUX "$@" PATH="$dir:$PATH" \
    fish --no-config -i -c "source '$SNIPPET'"
}

# ---------------------------------------------------------------------------
# Test 1: no MOSHI_CLIENT -> no tmux invocation at all
# ---------------------------------------------------------------------------
test_no_moshi() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log"
  [ ! -s "$dir/log" ] || { echo "  expected no calls, got:"; sed 's/^/    /' "$dir/log"; return 1; }
}
check "no MOSHI_CLIENT -> no tmux calls" test_no_moshi

# ---------------------------------------------------------------------------
# Test 2: MOSHI_CLIENT=1 but already inside tmux -> no tmux invocation
# ---------------------------------------------------------------------------
test_inside_tmux() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 TMUX=/tmp/fake-socket,1,0
  [ ! -s "$dir/log" ] || { echo "  expected no calls, got:"; sed 's/^/    /' "$dir/log"; return 1; }
}
check "MOSHI_CLIENT=1 inside tmux -> no tmux calls" test_inside_tmux

# ---------------------------------------------------------------------------
# Test 3: happy path — notes exists, no phone -> attach, no create/kill
# ---------------------------------------------------------------------------
test_happy_path() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=0 HAS_PHONE=1
  grep -Fxq "$ATTACH_LINE" "$dir/log" || { echo "  missing attach line"; return 1; }
  ! grep -Fq 'new-session -d -s notes' "$dir/log" || { echo "  unexpected notes create"; return 1; }
  ! grep -Fq 'kill-session' "$dir/log" || { echo "  unexpected kill-session"; return 1; }
}
check "notes exists, no phone -> attach only" test_happy_path

# ---------------------------------------------------------------------------
# Test 4: notes missing -> created detached before the attach
# ---------------------------------------------------------------------------
test_notes_created() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=1 HAS_PHONE=1
  grep -Fxq 'new-session -d -s notes' "$dir/log" || { echo "  missing notes create"; return 1; }
  grep -Fxq "$ATTACH_LINE" "$dir/log" || { echo "  missing attach line"; return 1; }
}
check "notes missing -> created detached, then attach" test_notes_created

# ---------------------------------------------------------------------------
# Test 5: stale ungrouped phone (resurrect artifact) -> killed before attach
# ---------------------------------------------------------------------------
test_stale_phone_killed() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=0 HAS_PHONE=0 PHONE_GROUP=phone
  grep -Fxq 'kill-session -t phone' "$dir/log" || { echo "  missing kill-session"; return 1; }
  grep -Fxq "$ATTACH_LINE" "$dir/log" || { echo "  missing attach line"; return 1; }
}
check "stale ungrouped phone -> killed, then attach" test_stale_phone_killed

# ---------------------------------------------------------------------------
# Test 6: phone already grouped with notes -> NOT killed, just attach
# ---------------------------------------------------------------------------
test_grouped_phone_kept() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=0 HAS_PHONE=0 PHONE_GROUP=notes
  ! grep -Fq 'kill-session' "$dir/log" || { echo "  unexpected kill-session"; return 1; }
  grep -Fxq "$ATTACH_LINE" "$dir/log" || { echo "  missing attach line"; return 1; }
}
check "grouped phone kept -> attach reuses it" test_grouped_phone_kept

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'
  for msg in "${fail_msgs[@]}"; do printf '  - %s\n' "$msg"; done
  exit 1
fi
