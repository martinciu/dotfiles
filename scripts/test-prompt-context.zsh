#!/usr/bin/env zsh
# Unit tests for _p9k_project_context.
# Run: zsh scripts/test-prompt-context.zsh
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

# ── function under test (stub — replace with real implementation in Task 3) ──
_p9k_project_context() {
  local projects="${PROJECTS_HOME:-$HOME/code}"
  if [[ -n $TMUX && $PWD == ${projects}/?* ]]; then
    local rel="${PWD#${projects}/}"
    local -a parts=("${(@s:/:)rel}")
    local out="${parts[1]}"
    local i
    for (( i=2; i<${#parts[@]}; i++ )); do
      out+="/${parts[i][1]}"
    done
    (( ${#parts[@]} > 1 )) && out+="/${parts[-1]}"
    _p9k_project_path="$out"
    typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='*'
  else
    unset _p9k_project_path
    typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
  fi
}

# ── helper: run context function with controlled env ─────────────────────────
# Uses zsh dynamic scoping: local TMUX/PWD/PROJECTS_HOME are visible inside
# _p9k_project_context when called from this helper.
_run() {
  local TMUX="$1" PWD="$2" PROJECTS_HOME="$3"
  unset _p9k_project_path POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN
  _p9k_project_context
}

# ── tests ────────────────────────────────────────────────────────────────────
echo
echo "_p9k_project_context"
echo "─────────────────────"

_run "1" "/p/myapp" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "myapp"  "project root → myapp"
assert_eq "${POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN:-__unset__}" "*" "project mode disables vcs"

_run "1" "/p/myapp/src" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "myapp/src"  "one subdir → myapp/src (no middle to shorten)"

_run "1" "/p/myapp/src/components" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "myapp/s/components"  "two subdirs → shorten middle"

_run "1" "/p/myapp/src/components/ui" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "myapp/s/c/ui"  "three subdirs → shorten two middle"

_run "" "/p/myapp" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "__unset__"  "no TMUX → project path unset"
assert_eq "${POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN:-__unset__}" "~" "no TMUX → vcs pattern restored to ~"

_run "1" "/p" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "__unset__"  "at PROJECTS_HOME root → not project mode"

_run "1" "/tmp/other" "/p"
assert_eq "${_p9k_project_path:-__unset__}"          "__unset__"  "outside PROJECTS_HOME → project path unset"
assert_eq "${POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN:-__unset__}" "~" "outside PROJECTS_HOME → vcs pattern restored to ~"

# ── summary ──────────────────────────────────────────────────────────────────
echo
echo "─────────────────────"
echo "passed: $pass"
echo "failed: $fail"
if (( fail > 0 )); then
  echo
  printf '%s\n' "${fail_msgs[@]}"
  exit 1
fi
exit 0
