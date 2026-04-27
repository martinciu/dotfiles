#!/usr/bin/env bash
# Smoke tests for the tmux helper scripts.
# Run from the repo root or anywhere — paths are absolute.
set -u

REPO="$PROJECTS_HOME/dotfiles"
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

  # main checkout — chipless rendering (no cyan), branch label on bar bg
  out=$("$GIT_STATUS" "$fixture" "#073642" "#586e75")
  assert_contains "$out" "main" "main checkout shows branch 'main'"
  if printf '%s' "$out" | grep -q -F -- "#2aa198"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  main checkout should not use cyan bg (chipless)"$'\n'"        got:  '$out'")
    echo "  FAIL  main checkout should not use cyan bg (chipless)"
  else
    pass=$((pass+1))
    echo "  PASS  main checkout omits cyan bg (chipless)"
  fi

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
  assert_contains "$out" "fg=#ff7770"  "ratio uses lifted red for deletions"
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
