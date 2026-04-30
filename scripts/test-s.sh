#!/usr/bin/env bash
# Smoke tests for bin/s.
# Invoked from scripts/test-helpers.sh; can also be run standalone.
#
# Manual smoke-test checklist (run these by hand after the suite passes):
#  1. Inside tmux session `dotfiles`, `s feature-x` -> new session
#     `dotfiles/feature-x` at the worktree path. Repeating `s feature-x`
#     -> switch-client to existing session, no second worktree created.
#  2. Outside tmux, `s` -> fzf picker -> pick `dotfiles` -> attach to
#     `dotfiles` session at ~/code/dotfiles.
#  3. Outside tmux, `s dotfiles feature-x` -> fresh `dotfiles/feature-x`
#     session with worktree at ~/code/dotfiles/.claude/worktrees/feature-x.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
S="$REPO/bin/s"

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
echo "bin/s"
echo "─────"

if [ ! -x "$S" ]; then
  echo "  SKIP — $S not present yet"
else
  # too many args -> usage
  out=$(env -u TMUX "$S" a b c 2>&1); rc=$?
  assert_eq "$rc" "1" "too many args -> exit 1"
  assert_contains "$out" "Usage:" "too many args -> usage on stderr"

  # ─── shim helpers ──────────────────────────
  # Each test creates a fresh shimdir, writes shims, and prepends to PATH.
  # Shims that record args write to "$shimdir/<name>.log".
  make_shimdir() { mktemp -d; }

  write_sesh_shim() {
    # $1 = shimdir, $2 = JSON to emit for `sesh list -c -j`
    local d="$1" json="$2"
    cat >"$d/sesh" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$d/sesh.log"
if [ "\$1" = "list" ]; then
  printf '%s\n' '$json'
  exit 0
fi
echo "sesh shim: unsupported args: \$*" >&2; exit 99
SHIM
    chmod +x "$d/sesh"
  }

  write_tmux_shim() {
    local d="$1"
    cat >"$d/tmux" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$d/tmux.log"
case "\$1" in
  has-session)
    if [ -f "$d/tmux.has_session_exit" ]; then
      exit "\$(cat "$d/tmux.has_session_exit")"
    fi
    exit 1
    ;;
  *)
    exit 0 ;;
esac
SHIM
    chmod +x "$d/tmux"
  }

  # ─── project lookup: not found ─────────────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/dotfiles"}]'
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" nope 2>&1); rc=$?
  assert_eq "$rc" "1" "explicit project not in sesh -> exit 1"
  assert_contains "$out" "no project named 'nope'" "explicit project not in sesh -> error message"
  rm -rf "$shimdir"

  # ─── project lookup: sesh missing -> meaningful error, not silent abort
  # Use a shimdir that shadows sesh (and jq/head) with nothing, but keep
  # system dirs so the zsh shebang still resolves. A no-op sesh shim that
  # exits non-zero simulates a broken/missing tool without stripping PATH.
  shimdir=$(make_shimdir)
  cat >"$shimdir/sesh" <<'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
  chmod +x "$shimdir/sesh"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" anything 2>&1); rc=$?
  assert_eq "$rc" "1" "sesh missing -> exit 1 (not 127)"
  assert_contains "$out" "no project named 'anything'" "sesh missing -> error message"
  rm -rf "$shimdir"

  # ─── picker: outside tmux, 0 args, mocked fzf auto-selects ─────────
  shimdir=$(make_shimdir)
  # Two real-repo fixtures + one non-repo to verify filtering.
  fixture=$(mktemp -d)
  mkdir -p "$fixture/dotfiles" "$fixture/strava"
  ( cd "$fixture/dotfiles" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m i )
  ( cd "$fixture/strava"   && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m i )
  json=$(printf '[{"Name":"home","Path":"%s"},{"Name":"dotfiles","Path":"%s"},{"Name":"strava","Path":"%s"}]' \
    "$fixture" "$fixture/dotfiles" "$fixture/strava")
  write_sesh_shim "$shimdir" "$json"
  write_tmux_shim "$shimdir"
  # fzf shim: log stdin, emit the first line back (auto-pick).
  cat >"$shimdir/fzf" <<'SHIM'
#!/usr/bin/env bash
input=$(cat)
echo "$input" >"$(dirname "$0")/fzf.stdin"
printf '%s\n' "$input" | head -n1
SHIM
  chmod +x "$shimdir/fzf"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" 2>&1); rc=$?
  assert_eq "$rc" "0" "picker auto-pick completes successfully"
  # The picker input must NOT contain the non-repo "home" entry.
  picker_in=$(cat "$shimdir/fzf.stdin")
  if printf '%s' "$picker_in" | grep -q '^home	'; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  picker should filter out non-repo 'home' entry"$'\n'"        input: '$picker_in'")
    echo "  FAIL  picker should filter out non-repo 'home' entry"
  else
    pass=$((pass+1))
    echo "  PASS  picker filters non-repo entries"
  fi
  rm -rf "$shimdir" "$fixture"

  # ─── picker: user cancels (fzf exits 130) -> clean exit 0 ──────────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp"}]'
  cat >"$shimdir/fzf" <<'SHIM'
#!/usr/bin/env bash
exit 130
SHIM
  chmod +x "$shimdir/fzf"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" 2>&1); rc=$?
  assert_eq "$rc" "0" "fzf cancel -> exit 0"
  rm -rf "$shimdir"

  # ─── infer project from cwd (inside tmux) ──────────────────────────
  shimdir=$(make_shimdir)
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m i )
  # Add a worktree so we can verify --git-common-dir resolves to the main repo.
  ( cd "$fixture" && git worktree add -q wt-x -b feat/x >/dev/null 2>&1 )
  # Use physical path (resolves macOS /var -> /private/var symlink) to match
  # what git rev-parse --path-format=absolute returns.
  fixture_real=$(cd "$fixture" && pwd -P)
  json=$(printf '[{"Name":"fixproject","Path":"%s"}]' "$fixture_real")
  write_sesh_shim "$shimdir" "$json"
  write_tmux_shim "$shimdir"
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$shimdir/wt.log"
printf '{"action":"created","branch":"feature-y","path":"$fixture_real/.claude/worktrees/feature-y"}\n'
SHIM
  chmod +x "$shimdir/wt"
  # Run from inside the worktree subdir.
  out=$( cd "$fixture/wt-x" && env TMUX=fake PATH="$shimdir:$PATH" "$S" feature-y 2>&1 ); rc=$?
  assert_eq "$rc" "0" "inferred-project flow completes (switch-client)"
  assert_contains "$(cat "$shimdir/tmux.log")" "switch-client -t fixproject/feature-y" \
    "infers project name 'fixproject' from cwd's main worktree path"
  rm -rf "$shimdir" "$fixture"

  # ─── infer fail: cwd not in any git repo ───────────────────────────
  shimdir=$(make_shimdir)
  fixture=$(mktemp -d)  # not a git repo
  write_sesh_shim "$shimdir" '[]'
  out=$( cd "$fixture" && env TMUX=fake PATH="$shimdir:$PATH" "$S" feature-y 2>&1 ); rc=$?
  assert_eq "$rc" "1" "cwd not in repo -> exit 1"
  assert_contains "$out" "not in a git repo" "cwd not in repo -> error message"
  rm -rf "$shimdir" "$fixture"

  # ─── infer fail: cwd's repo not in sesh config ─────────────────────
  shimdir=$(make_shimdir)
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m i )
  write_sesh_shim "$shimdir" '[{"Name":"otherproject","Path":"/some/other/path"}]'
  out=$( cd "$fixture" && env TMUX=fake PATH="$shimdir:$PATH" "$S" feature-y 2>&1 ); rc=$?
  assert_eq "$rc" "1" "cwd repo not in sesh -> exit 1"
  assert_contains "$out" "cwd's repo is not in your sesh config" "cwd repo not in sesh -> error message"
  rm -rf "$shimdir" "$fixture"

  # ─── worktree creation: 2-arg flow invokes wt with correct args ────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/fakerepo"}]'
  write_tmux_shim "$shimdir"
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$shimdir/wt.log"
# Emit the same JSON shape as real wt --format=json
printf '{"action":"created","branch":"feature-x","path":"/tmp/fakerepo/.claude/worktrees/feature-x"}\n'
SHIM
  chmod +x "$shimdir/wt"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" dotfiles feature-x 2>&1); rc=$?
  assert_eq "$rc" "0" "2-arg flow completes after wt (attach)"
  wt_args=$(cat "$shimdir/wt.log")
  assert_contains "$wt_args" "-C /tmp/fakerepo switch --create --no-cd --format=json feature-x" \
    "wt invoked with -C <project_path> switch --create --no-cd --format=json <name>"
  rm -rf "$shimdir"

  # ─── 1-arg out: session=<project>, no worktree, no wt call ─────────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/fakerepo"}]'
  write_tmux_shim "$shimdir"
  # wt shim that fails loudly if invoked
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "wt should not be called in 1-arg-out flow" >&2; exit 99
SHIM
  chmod +x "$shimdir/wt"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" dotfiles 2>&1); rc=$?
  assert_eq "$rc" "0" "1-arg-out happy path -> exit 0"
  log=$(cat "$shimdir/tmux.log")
  assert_contains "$log" "has-session -t dotfiles" "1-arg-out checks has-session for project name"
  assert_contains "$log" "new-session -d -s dotfiles -c /tmp/fakerepo" \
    "1-arg-out creates tmux session at project path"
  assert_contains "$log" "attach -t dotfiles" "1-arg-out attaches (TMUX unset)"
  rm -rf "$shimdir"

  # ─── 2-arg out: session=<project>/<name>, wt creates worktree ──────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/fakerepo"}]'
  write_tmux_shim "$shimdir"
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$shimdir/wt.log"
printf '{"action":"created","branch":"feature-x","path":"/tmp/fakerepo/.claude/worktrees/feature-x"}\n'
SHIM
  chmod +x "$shimdir/wt"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" dotfiles feature-x 2>&1); rc=$?
  assert_eq "$rc" "0" "2-arg out happy path -> exit 0"
  log=$(cat "$shimdir/tmux.log")
  assert_contains "$log" "new-session -d -s dotfiles/feature-x -c /tmp/fakerepo/.claude/worktrees/feature-x" \
    "2-arg-out creates tmux session named <project>/<name> at worktree path"
  assert_contains "$log" "attach -t dotfiles/feature-x" "2-arg-out attaches (TMUX unset)"
  rm -rf "$shimdir"

  # ─── 2-arg in tmux: switch-client instead of attach ─────────────────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/fakerepo"}]'
  write_tmux_shim "$shimdir"
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$shimdir/wt.log"
printf '{"action":"created","branch":"feature-x","path":"/tmp/fakerepo/.claude/worktrees/feature-x"}\n'
SHIM
  chmod +x "$shimdir/wt"
  out=$(env TMUX=fake PATH="$shimdir:$PATH" "$S" dotfiles feature-x 2>&1); rc=$?
  assert_eq "$rc" "0" "2-arg in tmux happy path -> exit 0"
  log=$(cat "$shimdir/tmux.log")
  assert_contains "$log" "switch-client -t dotfiles/feature-x" \
    "2-arg-in uses switch-client (TMUX set)"
  if printf '%s' "$log" | grep -q "attach -t"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  in-tmux must not use 'attach -t'"$'\n'"        log: '$log'")
    echo "  FAIL  in-tmux must not use 'attach -t'"
  else
    pass=$((pass+1))
    echo "  PASS  in-tmux does not use 'attach -t'"
  fi
  rm -rf "$shimdir"

  # ─── has-session short-circuit: no wt call, no new-session ─────────
  shimdir=$(make_shimdir)
  write_sesh_shim "$shimdir" '[{"Name":"dotfiles","Path":"/tmp/fakerepo"}]'
  write_tmux_shim "$shimdir"
  echo 0 >"$shimdir/tmux.has_session_exit"   # session "exists"
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "wt should not be called when session already exists" >&2; exit 99
SHIM
  chmod +x "$shimdir/wt"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" dotfiles feature-x 2>&1); rc=$?
  assert_eq "$rc" "0" "has-session=0 short-circuit -> exit 0"
  log=$(cat "$shimdir/tmux.log")
  if printf '%s' "$log" | grep -q "new-session"; then
    fail=$((fail+1))
    fail_msgs+=("FAIL  has-session=0 should skip new-session"$'\n'"        log: '$log'")
    echo "  FAIL  has-session=0 should skip new-session"
  else
    pass=$((pass+1))
    echo "  PASS  has-session=0 skips new-session"
  fi
  assert_contains "$log" "attach -t dotfiles/feature-x" "has-session=0 still attaches"
  rm -rf "$shimdir"

  # ─── 0-arg picker -> session=<project>, no worktree ────────────────
  shimdir=$(make_shimdir)
  fixture=$(mktemp -d)
  mkdir -p "$fixture/dotfiles"
  ( cd "$fixture/dotfiles" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m i )
  fixture_real=$(cd "$fixture/dotfiles" && pwd -P)
  json=$(printf '[{"Name":"dotfiles","Path":"%s"}]' "$fixture_real")
  write_sesh_shim "$shimdir" "$json"
  write_tmux_shim "$shimdir"
  cat >"$shimdir/fzf" <<'SHIM'
#!/usr/bin/env bash
head -n1
SHIM
  chmod +x "$shimdir/fzf"
  out=$(env -u TMUX PATH="$shimdir:$PATH" "$S" 2>&1); rc=$?
  assert_eq "$rc" "0" "picker happy path -> exit 0"
  log=$(cat "$shimdir/tmux.log")
  assert_contains "$log" "new-session -d -s dotfiles -c $fixture_real" \
    "picker creates session at picked project path"
  rm -rf "$shimdir" "$fixture"

  # ─── 1-arg in tmux: session=<project>/<name>, wt creates worktree ──
  shimdir=$(make_shimdir)
  fixture=$(mktemp -d)
  ( cd "$fixture" && git init -q && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m i )
  fixture_real=$(cd "$fixture" && pwd -P)
  json=$(printf '[{"Name":"fixproject","Path":"%s"}]' "$fixture_real")
  write_sesh_shim "$shimdir" "$json"
  write_tmux_shim "$shimdir"
  cat >"$shimdir/wt" <<SHIM
#!/usr/bin/env bash
echo "\$@" >>"$shimdir/wt.log"
printf '{"action":"created","branch":"feature-y","path":"$fixture_real/.claude/worktrees/feature-y"}\n'
SHIM
  chmod +x "$shimdir/wt"
  out=$( cd "$fixture" && env TMUX=fake PATH="$shimdir:$PATH" "$S" feature-y 2>&1 ); rc=$?
  assert_eq "$rc" "0" "1-arg in-tmux happy path -> exit 0"
  log=$(cat "$shimdir/tmux.log")
  assert_contains "$log" "new-session -d -s fixproject/feature-y -c $fixture_real/.claude/worktrees/feature-y" \
    "1-arg in-tmux creates session named <inferred-project>/<name> at worktree"
  assert_contains "$log" "switch-client -t fixproject/feature-y" \
    "1-arg in-tmux uses switch-client"
  rm -rf "$shimdir" "$fixture"
fi

# ─── Summary ────────────────────────────────
echo
echo "─────────────────"
echo "test-s.sh passed: $pass"
echo "test-s.sh failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
