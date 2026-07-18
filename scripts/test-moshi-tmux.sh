#!/opt/homebrew/bin/bash
# Smoke tests for conf.d/50-moshi-tmux.fish (Moshi login -> twin attach).
#
# Each test builds a tmpdir with a mock `tmux` that logs every invocation
# ("$*" per line) and answers has-session from the HAS_NOTES exit-code
# fixture, plus a mock tmux-phone-twin under a fake $HOME (the snippet
# calls it via ~/.config/tmux/bin/…) that prints $TWIN_OUT or fails when
# it's empty. The snippet is sourced under `fish --no-config -i -c` so its
# `status is-interactive` gate passes; `env -u TMUX` clears the outer tmux.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPET="$REPO/.config/fish/conf.d/50-moshi-tmux.fish"

ATTACH_LINE='attach-session -t =notes-phone ; set destroy-unattached on'
FALLBACK_LINE='new-session -A -s notes'

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

# Build the mock tmux in $1/bin and a mock tmux-phone-twin under the fake
# HOME $1/home (the snippet calls it via ~/.config/tmux/bin/…). Both log
# "$*" lines; the twin mock prints $TWIN_OUT (fails when empty).
build_shim() {
  local dir="$1" log="$2"
  mkdir -p "$dir/bin" "$dir/home/.config/tmux/bin"

  cat > "$dir/bin/tmux" <<EOF
#!/opt/homebrew/bin/bash
echo "\$*" >> "$log"
case "\$1" in
  has-session)
    case "\$*" in
      *"-t =notes"*) exit "\${HAS_NOTES:-1}" ;;
    esac
    ;;
esac
exit 0
EOF
  chmod +x "$dir/bin/tmux"

  cat > "$dir/home/.config/tmux/bin/tmux-phone-twin" <<EOF
#!/opt/homebrew/bin/bash
echo "phone-twin \$*" >> "$log"
[ -n "\${TWIN_OUT:-}" ] || exit 1
printf '%s\n' "\$TWIN_OUT"
EOF
  chmod +x "$dir/home/.config/tmux/bin/tmux-phone-twin"
}

# run_snippet <dir> <log> [VAR=val ...] — source the snippet with the shim
# first on PATH, the fake HOME, and the given env fixtures. TMUX is cleared
# unless a fixture re-sets it.
run_snippet() {
  local dir="$1" log="$2"; shift 2
  env -u TMUX "$@" HOME="$dir/home" PATH="$dir/bin:$PATH" \
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
# Test 3: happy path — notes exists, twin script succeeds -> twin attach
# ---------------------------------------------------------------------------
test_happy_path() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=0 TWIN_OUT=notes-phone
  grep -Fxq 'phone-twin notes' "$dir/log" || { echo "  twin script not called"; return 1; }
  grep -Fxq "$ATTACH_LINE" "$dir/log" || { echo "  missing attach line"; return 1; }
  ! grep -Fq 'new-session' "$dir/log" || { echo "  unexpected new-session"; return 1; }
}
check "notes exists -> twin attach, no create" test_happy_path

# ---------------------------------------------------------------------------
# Test 4: notes missing -> created detached first, then twin attach
# ---------------------------------------------------------------------------
test_notes_created() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=1 TWIN_OUT=notes-phone
  grep -Fxq 'new-session -d -s notes' "$dir/log" || { echo "  missing notes create"; return 1; }
  grep -Fxq "$ATTACH_LINE" "$dir/log" || { echo "  missing attach line"; return 1; }
}
check "notes missing -> created detached, then twin attach" test_notes_created

# ---------------------------------------------------------------------------
# Test 5: twin script fails -> plain new-session -A fallback
# ---------------------------------------------------------------------------
test_twin_failure_fallback() {
  local dir; dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  build_shim "$dir" "$dir/log"
  run_snippet "$dir" "$dir/log" MOSHI_CLIENT=1 HAS_NOTES=0 TWIN_OUT=
  grep -Fxq "$FALLBACK_LINE" "$dir/log" || { echo "  missing fallback attach"; return 1; }
  ! grep -Fq 'attach-session' "$dir/log" || { echo "  unexpected twin attach"; return 1; }
}
check "twin failure -> plain new-session -A fallback" test_twin_failure_fallback

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'
  for msg in "${fail_msgs[@]}"; do printf '  - %s\n' "$msg"; done
  exit 1
fi
