#!/usr/bin/env bash
# Smoke tests for the <prefix> u URL picker wrapper.
#
# Two contract checks against the wfxr/tmux-fzf-url plugin we depend on:
#   1. Sourcing fzf-url.sh with __FZF_URL_TESTING=1 imports the helpers
#      we need (xre_extract, fzf_filter, open_url, get_copy_cmd,
#      ensure_xre, PAT_URL) WITHOUT running the plugin's main flow.
#   2. `tail -r` | xre_extract emits the LATEST occurrence of a duplicated
#      URL ahead of an inline unique URL — the property the wrapper relies
#      on. (`tail -r` is BSD/macOS; we don't depend on GNU coreutils' `tac`.)
#
# Plus one wrapper-presence check (the wrapper itself).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$HOME/.config/tmux/plugins/tmux-fzf-url"
WRAPPER="$REPO/.config/tmux/bin/tmux-fzf-url-newest"

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

# ---------------------------------------------------------------------------
# Test 1: plugin source guard imports the helpers we need
# ---------------------------------------------------------------------------
test_source_guard() {
  [ -d "$PLUGIN_DIR" ] || { echo "  plugin not installed at $PLUGIN_DIR"; return 1; }

  bash -c '
    set -e
    __FZF_URL_TESTING=1 source "'"$PLUGIN_DIR"'/fzf-url.sh"
    for fn in xre_extract fzf_filter open_url get_copy_cmd ensure_xre; do
      declare -F "$fn" >/dev/null || { echo "  missing function: $fn" >&2; exit 1; }
    done
    [ -n "${PAT_URL:-}" ] || { echo "  PAT_URL not set" >&2; exit 1; }
  '
}
check "source guard imports xre_extract/fzf_filter/open_url/get_copy_cmd/ensure_xre/PAT_URL" \
  test_source_guard

# ---------------------------------------------------------------------------
# Test 2: `tail -r` | xre_extract puts late occurrence of a duplicated URL
# before a unique URL that appeared between its early and late occurrences.
# ---------------------------------------------------------------------------
test_latest_occurrence_wins() {
  [ -d "$PLUGIN_DIR" ] || { echo "  plugin not installed at $PLUGIN_DIR"; return 1; }
  [ -x "$PLUGIN_DIR/bin/xre" ] || { echo "  xre binary not present at $PLUGIN_DIR/bin/xre"; return 1; }

  local out
  out="$(bash -c '
    set -e
    __FZF_URL_TESTING=1 source "'"$PLUGIN_DIR"'/fzf-url.sh"
    printf "%s\n" \
      "early line https://example.com/duped" \
      "middle    https://example.com/unique" \
      "late line https://example.com/duped" \
      | tail -r | xre_extract
  ')"

  local first_line second_line
  first_line="$(printf '%s\n' "$out" | sed -n '1p')"
  second_line="$(printf '%s\n' "$out" | sed -n '2p')"
  [ "$first_line" = "https://example.com/duped" ] || { echo "  line 1 was '$first_line', expected 'https://example.com/duped'"; return 1; }
  [ "$second_line" = "https://example.com/unique" ] || { echo "  line 2 was '$second_line', expected 'https://example.com/unique'"; return 1; }
}
check "tail -r | xre_extract emits late-duplicate before mid-unique" \
  test_latest_occurrence_wins

# ---------------------------------------------------------------------------
# Test 3: wrapper exists and is executable
# ---------------------------------------------------------------------------
test_wrapper_executable() {
  [ -x "$WRAPPER" ] || { echo "  $WRAPPER is not executable (or missing)"; return 1; }
}
check "wrapper $WRAPPER exists and is executable" \
  test_wrapper_executable

# ---------------------------------------------------------------------------
# Test 4: wrapper exits 0 when the fzf picker is cancelled with ESC.
# fzf returns 130 on ESC; with `set -euo pipefail` that propagates as the
# wrapper's own exit code, and tmux's `run -b` then surfaces it as
# `'... tmux-fzf-url-newest 50000' returned 130`. Mock tmux + fzf-tmux to
# simulate ESC and assert the wrapper finishes silently.
# ---------------------------------------------------------------------------
test_esc_exits_zero() {
  [ -d "$PLUGIN_DIR" ] || { echo "  plugin not installed at $PLUGIN_DIR"; return 1; }
  [ -x "$PLUGIN_DIR/bin/xre" ] || { echo "  xre binary not present at $PLUGIN_DIR/bin/xre"; return 1; }

  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  cat > "$tmpdir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  capture-pane) printf 'visit https://example.com today\n' ;;
  show)         printf '%s\n' '-w 70% -h 70% --multi -0 --no-preview --border --tac' ;;
  display)      ;;
  *)            ;;
esac
EOF
  chmod +x "$tmpdir/tmux"

  cat > "$tmpdir/fzf-tmux" <<'EOF'
#!/usr/bin/env bash
exit 130
EOF
  chmod +x "$tmpdir/fzf-tmux"

  local status=0
  PATH="$tmpdir:$PATH" "$WRAPPER" 100 >/dev/null 2>&1 || status=$?
  [ "$status" -eq 0 ] || { echo "  wrapper exited $status, expected 0 (ESC cancellation should be silent)"; return 1; }
}
check "wrapper exits 0 when fzf is cancelled with ESC (exit 130)" \
  test_esc_exits_zero

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'
  for msg in "${fail_msgs[@]}"; do printf '  - %s\n' "$msg"; done
  exit 1
fi
