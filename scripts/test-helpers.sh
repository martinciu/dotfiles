#!/opt/homebrew/bin/bash
# Smoke tests for the tmux helper scripts.
# Run from the repo root or anywhere — paths are absolute.
set -u

REPO="${REPO:-$PROJECTS_HOME/dotfiles}"
GIT_STATUS="$REPO/.config/tmux/bin/tmux-git-status"

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

# Stub `tmux` for the helper sections below, so tmux-git-status cannot reach
# the live server. `show-option` then returns empty and the
# `: "${var:=<solarized-hex>}"` fallbacks inside the helper take over — which
# is what the colour assertions here are written against. Without it the
# helper reads whatever theme is currently active and 6 assertions fail on any
# non-Solarized theme (#395). Same shim, same reason, as
# scripts/test-tmux-pr-status.sh.
TMUX_STUB_DIR=$(mktemp -d)
cat > "$TMUX_STUB_DIR/tmux" <<'TMUXSTUB'
#!/opt/homebrew/bin/bash
# Shim: show-option returns empty (triggers Solarized fallbacks); all else no-ops.
exit 0
TMUXSTUB
chmod +x "$TMUX_STUB_DIR/tmux"
_SAVED_PATH="$PATH"
export PATH="$TMUX_STUB_DIR:$PATH"

# ─── tmux-git-status ────────────────────────
echo
echo "tmux-git-status"
echo "───────────────"

if [ ! -x "$GIT_STATUS" ]; then
  echo "  SKIP — $GIT_STATUS not present yet"
else
  fixture=$(mktemp -d)
  (
    cd "$fixture"
    git init -q -b main
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m "init"
    # secondary worktree where branch name MATCHES dir name
    git worktree add -q same -b same >/dev/null 2>&1
    # secondary worktree where branch name DIFFERS from dir name
    git worktree add -q wt-foo -b feat/bar >/dev/null 2>&1
  )

  # main checkout — violet chip rendering, branch label on violet bg
  out=$("$GIT_STATUS" "$fixture" "#073642" "#586e75")
  assert_contains "$out" "main" "main checkout shows branch 'main'"
  assert_contains "$out" "#6c71c4" "main checkout uses violet bg"

  # worktree where branch == dir name → no wt: suffix, yellow chip
  out=$("$GIT_STATUS" "$fixture/same" "#073642" "#586e75")
  assert_contains "$out" "same" "wt with matching name shows branch"
  assert_contains "$out" "#b58900" "wt with matching name uses yellow bg"
  if printf '%s' "$out" | grep -q "wt:"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  wt with matching name should not show 'wt:' suffix"$'\n'"        got:  '$out'")
    echo "  FAIL  wt with matching name should not show 'wt:' suffix"
  else
    pass=$((pass+1))
    echo "  PASS  wt with matching name suppresses 'wt:' suffix"
  fi

  # worktree where branch != dir name → wt:NAME suffix, yellow chip
  out=$("$GIT_STATUS" "$fixture/wt-foo" "#073642" "#586e75")
  assert_contains "$out" "feat/bar" "wt with differing name shows branch"
  assert_contains "$out" "wt:wt-foo" "wt with differing name shows 'wt:wt-foo'"
  assert_contains "$out" "#b58900" "wt with differing name uses yellow bg"

  # not a git repo → empty output
  not_repo=$(mktemp -d)
  out=$("$GIT_STATUS" "$not_repo" "#073642" "#586e75")
  assert_eq "$out" "" "non-git dir -> empty output"

  # ─── flush-right mode (empty next-bg) ──────────
  # tri_r is U+E0B4 (\xee\x82\xb4) — must be ABSENT when next-bg is empty.
  # tri_l is U+E0B6 (\xee\x82\xb6) — must still be present.
  out=$("$GIT_STATUS" "$fixture" "#073642" "")
  if printf '%s' "$out" | grep -q -F -- $'\xee\x82\xb4'; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  flush-right mode should not emit tri_r"$'\n'"        got:  '$out'")
    echo "  FAIL  flush-right mode should not emit tri_r"
  else
    pass=$((pass+1))
    echo "  PASS  flush-right mode omits closing tri_r (U+E0B4)"
  fi
  assert_contains "$out" $'\xee\x82\xb6' "flush-right mode still emits opening tri_l (U+E0B6)"
  assert_contains "$out" "main" "flush-right mode still shows branch label"

  rm -rf "$fixture" "$not_repo"

  # ─── change-info markers ────────────────────
  # A repo with an upstream so we can exercise ahead/behind too.
  changes_repo=$(mktemp -d)
  upstream=$(mktemp -d)
  clone_dir=$(mktemp -d)
  (
    cd "$upstream" && git init -q --bare -b main
    cd "$changes_repo"
    git init -q -b main
    git config user.email t@t
    git config user.name  t
    git commit --allow-empty -q -m "init"
    git remote add origin "$upstream"
    git push -q -u origin main
  )

  # Clean + synced — none of the change markers should appear.
  out=$("$GIT_STATUS" "$changes_repo" "#073642" "#586e75")
  for marker in '+' '-' '?' $'\xe2\x86\x91' $'\xe2\x86\x93'; do
    if printf '%s' "$out" | grep -q -F -- "$marker"; then
      fail=$((fail+1))
      fail_msgs+=("FAIL  clean+synced repo should not contain '$marker'"$'\n'"        got:  '$out'")
      echo "  FAIL  clean+synced repo should not contain '$marker'"
    else
      pass=$((pass+1))
      echo "  PASS  clean+synced repo lacks '$marker'"
    fi
  done

  # Untracked file → "1?"
  ( cd "$changes_repo" && : > new.txt )
  out=$("$GIT_STATUS" "$changes_repo" "#073642" "#586e75")
  assert_contains "$out" "1?" "untracked file -> 1?"
  ( cd "$changes_repo" && rm -f new.txt )

  # Staged new file (1 line) → "1" in lifted green (ins-only path, no slash)
  (
    cd "$changes_repo"
    echo a > a.txt
    git add a.txt
  )
  out=$("$GIT_STATUS" "$changes_repo" "#073642" "#586e75")
  assert_contains "$out" "fg=#b8d65c]1" "ins-only emits ins fg directive followed by '1'"
  if printf '%s' "$out" | grep -q -F -- "/"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  ins-only path should not contain '/'"$'\n'"        got:  '$out'")
    echo "  FAIL  ins-only path should not contain '/'"
  else
    pass=$((pass+1))
    echo "  PASS  ins-only path has no slash separator"
  fi
  ( cd "$changes_repo" && git commit -q -m "add a" && git push -q )

  # Replace 1 line with 2 → "2/1" inline ratio with both colors. The literal
  # "2/1" substring is split by tmux color directives, so strip them first.
  ( cd "$changes_repo" && printf 'b\nc\n' > a.txt )
  out=$("$GIT_STATUS" "$changes_repo" "#073642" "#586e75")
  out_plain=$(printf '%s' "$out" | sed 's/#\[[^]]*\]//g')
  assert_contains "$out_plain" "2/1"   "both ins+del renders as '2/1' ratio"
  assert_contains "$out" "fg=#b8d65c"  "ratio uses lifted green for insertions"
  assert_contains "$out" "fg=#ff9b96"  "ratio uses softer red for deletions on violet chip"
  ( cd "$changes_repo" && git commit -q -am "edit a" && git push -q )

  # Ahead by 1 → "↑1"
  ( cd "$changes_repo" && git commit --allow-empty -q -m "ahead" )
  out=$("$GIT_STATUS" "$changes_repo" "#073642" "#586e75")
  assert_contains "$out" $'\xe2\x86\x91''1' "ahead by 1 -> ↑1"
  ( cd "$changes_repo" && git push -q )

  # Behind by 1 → "↓1" (push from a separate clone, fetch into the fixture)
  (
    cd "$clone_dir"
    git clone -q "$upstream" repo
    cd repo
    git config user.email t@t
    git config user.name  t
    git commit --allow-empty -q -m "remote-only"
    git push -q
  )
  ( cd "$changes_repo" && git fetch -q origin )
  out=$("$GIT_STATUS" "$changes_repo" "#073642" "#586e75")
  assert_contains "$out" $'\xe2\x86\x93''1' "behind by 1 -> ↓1"

  rm -rf "$changes_repo" "$upstream" "$clone_dir"
fi

# Helper sections done — drop the tmux stub so the rest of the script sees the
# real environment again.
PATH="$_SAVED_PATH"; export PATH
rm -rf "$TMUX_STUB_DIR"

# ─── glow ───────────────────────────────────
echo
echo "glow"
echo "────"

if ! command -v glow >/dev/null 2>&1; then
  echo "  SKIP — glow not installed (run 'brew bundle')"
else
  # glow is a MIXED-DIR tool: ~/.config/glow is a real directory holding
  # per-file symlinks to the repo's tracked glamour-<theme>.json, plus a
  # machine-local glamour.json that theme-set points at the active one. The
  # repo therefore has no glamour.json of its own — $REPO/.config/glow/
  # glamour.json never exists, and asserting against it fails on a correctly
  # bootstrapped machine (#398).
  #
  # Assert the path the real code uses. functions/md.fish:12 resolves
  # `$HOME/.config/glow/glamour.json`, so that is what these check.
  glamour_json="$HOME/.config/glow/glamour.json"

  # Shape: the active pointer must resolve to one of the repo's tracked
  # per-theme files. Deliberately not pinned to a specific theme — theme-set
  # repoints it on every flip, and any glamour-*.json in the repo is correct.
  glamour_target=$(cd "$(dirname "$glamour_json")" 2>/dev/null && readlink -f "$glamour_json" 2>/dev/null)
  case "$glamour_target" in
    "$REPO/.config/glow/glamour-"*.json)
      pass=$((pass+1)); echo "  PASS  ~/.config/glow/glamour.json resolves to a tracked glamour-<theme>.json"
      ;;
    *)
      fail=$((fail+1))
      fail_msgs+=("FAIL  ~/.config/glow/glamour.json does not resolve into dotfiles"$'\n'"        got:  '${glamour_target:-<unresolved>}'"$'\n'"        want: $REPO/.config/glow/glamour-<theme>.json")
      echo "  FAIL  ~/.config/glow/glamour.json does not resolve into dotfiles"
      ;;
  esac

  # JSON parse check (uses python3, available on macOS by default).
  if python3 -m json.tool "$glamour_json" >/dev/null 2>&1; then
    pass=$((pass+1)); echo "  PASS  glamour.json parses as JSON"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  glamour.json failed to parse")
    echo "  FAIL  glamour.json failed to parse"
  fi

  # End-to-end: render a small fixture from stdin via the same flag md uses.
  # Exit 0, non-empty output.
  if out=$(printf '# Hi\n\n**bold**\n' | glow --style "$glamour_json" - 2>/dev/null) && [ -n "$out" ]; then
    pass=$((pass+1)); echo "  PASS  stdin render via --style exits 0 with non-empty output"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  stdin render failed or empty"$'\n'"        out: '$out'")
    echo "  FAIL  stdin render failed or empty"
  fi

  # Render an actual repo file (catches stylesheet parse regressions).
  if glow --style "$glamour_json" "$REPO/README.md" >/dev/null 2>&1; then
    pass=$((pass+1)); echo "  PASS  glow --style glamour.json README.md exits 0"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  glow refused glamour.json on README.md")
    echo "  FAIL  glow refused glamour.json on README.md"
  fi
fi

if ! bash "$(dirname "$0")/test-s.sh"; then
  fail=$((fail+1))
  fail_msgs+=("FAIL  scripts/test-s.sh reported failures")
fi

if ! bash "$(dirname "$0")/test-i.sh"; then
  fail=$((fail+1))
  fail_msgs+=("FAIL  scripts/test-i.sh reported failures")
fi

# ─── Summary ────────────────────────────────
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
