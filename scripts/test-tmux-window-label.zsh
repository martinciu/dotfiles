#!/usr/bin/env zsh
# Unit tests for _tmux_window_label.
# Run: zsh scripts/test-tmux-window-label.zsh
set -u

pass=0; fail=0; fail_msgs=()

assert_eq() {
  local got="$1" want="$2" desc="$3"
  if [[ "$got" == "$want" ]]; then
    pass=$((pass+1)); echo "  PASS  $desc"
  else
    fail=$((fail+1))
    fail_msgs+=("FAIL  $desc"$'\n'"        got:  '$got'"$'\n'"        want: '$want'")
    echo "  FAIL  $desc"
  fi
}

# ── function under test ──────────────────────────────────────────────────────
# Keep in sync with .zshrc
_tmux_window_label() {
  emulate -L zsh
  local cmd="$1"
  # Strip leading KEY=value tokens (each followed by whitespace, or end-of-string).
  while [[ $cmd =~ '^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*([[:space:]]+|$)' ]]; do
    cmd="${cmd#$MATCH}"
  done
  local -a words=( ${=cmd} )
  case $#words in
    0) _tmux_window_label_out="" ;;
    1) _tmux_window_label_out="${words[1]}" ;;
    *) _tmux_window_label_out="${words[1]} ${words[2]}" ;;
  esac
}

# ── helper: invoke function and capture output via global ────────────────────
_run() {
  _tmux_window_label_out=""
  _tmux_window_label "$1"
}

# ── tests ────────────────────────────────────────────────────────────────────
echo
echo "_tmux_window_label"
echo "──────────────────"

_run "git push origin main"
assert_eq "$_tmux_window_label_out" "git push" "two-word command → first two words"

_run "RAILS_ENV=test bundle exec rspec spec/foo"
assert_eq "$_tmux_window_label_out" "bundle exec" "leading env var stripped"

_run "DEBUG=1 npm run dev"
assert_eq "$_tmux_window_label_out" "npm run" "single env var + multi-word command"

_run "BUNDLE_GEMFILE=Gemfile.next RAILS_ENV=test bundle exec rspec"
assert_eq "$_tmux_window_label_out" "bundle exec" "two leading env vars stripped"

_run "nvim"
assert_eq "$_tmux_window_label_out" "nvim" "single-word command"

_run "git log | head -5"
assert_eq "$_tmux_window_label_out" "git log" "pipe → first two whitespace-separated tokens"

_run "cd ~/projects"
assert_eq "$_tmux_window_label_out" "cd ~/projects" "cd with single arg → both words"

_run ""
assert_eq "$_tmux_window_label_out" "" "empty input → empty label"

_run "FOO=bar"
assert_eq "$_tmux_window_label_out" "" "env var alone → empty label"

_run "FOO=bar BAZ=qux ls -la"
assert_eq "$_tmux_window_label_out" "ls -la" "multiple env vars → stripped, then first two words"

_run "  git   status  "
assert_eq "$_tmux_window_label_out" "git status" "extra whitespace collapses"

# ── summary ──────────────────────────────────────────────────────────────────
echo
echo "──────────────────"
echo "passed: $pass"
echo "failed: $fail"
if (( fail > 0 )); then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
