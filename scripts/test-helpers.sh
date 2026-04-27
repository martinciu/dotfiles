#!/usr/bin/env bash
# Smoke tests for the tmux helper scripts.
# Run from the repo root or anywhere — paths are absolute.
set -u

REPO="$HOME/projects/dotfiles"
PROJ_NAME="$REPO/.config/tmux/bin/tmux-project-name"
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

# ─── tmux-project-name ──────────────────────
echo
echo "tmux-project-name"
echo "─────────────────"

if [ ! -x "$PROJ_NAME" ]; then
  echo "  SKIP — $PROJ_NAME not present yet"
else
  fake_projects=$(mktemp -d)
  mkdir -p "$fake_projects/chopin/sub/dir"
  mkdir -p "$fake_projects/rater"

  out=$(PROJECTS_HOME="$fake_projects" "$PROJ_NAME" "$fake_projects/chopin/sub/dir")
  assert_eq "$out" "chopin" "deep path under PROJECTS_HOME -> top-level dir"

  out=$(PROJECTS_HOME="$fake_projects" "$PROJ_NAME" "$fake_projects/rater")
  assert_eq "$out" "rater" "exact project root"

  out=$(PROJECTS_HOME="$fake_projects" "$PROJ_NAME" "/tmp")
  assert_eq "$out" "" "outside PROJECTS_HOME -> empty"

  out=$(PROJECTS_HOME="$fake_projects" "$PROJ_NAME" "$fake_projects")
  assert_eq "$out" "" "exactly PROJECTS_HOME -> empty"

  rm -rf "$fake_projects"
fi

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

  # main checkout — cyan chip implied via bg color
  out=$("$GIT_STATUS" "$fixture" "#073642" "#586e75")
  assert_contains "$out" "main" "main checkout shows branch 'main'"
  assert_contains "$out" "#2aa198" "main checkout uses cyan bg"

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

  rm -rf "$fixture" "$not_repo"
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
