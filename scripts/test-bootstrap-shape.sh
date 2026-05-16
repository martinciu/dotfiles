#!/opt/homebrew/bin/bash
# Asserts the post-bootstrap shape of ~/.config/{fish,nvim,worktrunk}/.
# Run AFTER bootstrap.sh on the live machine. Fails if any leaked file
# is back inside the repo working tree, or any required symlink is missing.
set -u

REPO="${REPO:-$PROJECTS_HOME/dotfiles}"

pass=0
fail=0
fail_msgs=()

# ─── helpers ────────────────────────────────
record_pass() { pass=$((pass+1)); echo "  PASS  $1"; }
record_fail() {
  fail=$((fail+1))
  fail_msgs+=("FAIL  $1"$'\n'"        $2")
  echo "  FAIL  $1"
}

assert_real_dir() {
  local path="$1" desc="$2"
  if [ -L "$path" ]; then
    record_fail "$desc" "expected real dir, found symlink: $path → $(readlink "$path")"
  elif [ ! -d "$path" ]; then
    record_fail "$desc" "expected real dir, missing: $path"
  else
    record_pass "$desc"
  fi
}

assert_symlink_to() {
  local path="$1" want_target="$2" desc="$3"
  if [ ! -L "$path" ]; then
    record_fail "$desc" "expected symlink, not a symlink: $path"
  elif [ "$(readlink "$path")" != "$want_target" ]; then
    record_fail "$desc" "symlink target mismatch: $path → $(readlink "$path"), want → $want_target"
  else
    record_pass "$desc"
  fi
}

assert_real_file() {
  local path="$1" desc="$2"
  if [ -L "$path" ]; then
    record_fail "$desc" "expected real file, found symlink: $path → $(readlink "$path")"
  elif [ ! -f "$path" ]; then
    record_fail "$desc" "expected real file, missing: $path"
  else
    record_pass "$desc"
  fi
}

assert_not_in_repo() {
  local path="$1" desc="$2"
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    record_fail "$desc" "leaked into repo working tree: $path"
  else
    record_pass "$desc"
  fi
}

# ─── fish ───────────────────────────────────
echo
echo "fish layout"
echo "───────────"
assert_real_dir   "$HOME/.config/fish"                              "~/.config/fish/ is a real dir"
assert_real_dir   "$HOME/.config/fish/conf.d"                       "~/.config/fish/conf.d/ is a real dir"
assert_symlink_to "$HOME/.config/fish/config.fish"     "$REPO/.config/fish/config.fish"     "config.fish symlink"
assert_symlink_to "$HOME/.config/fish/completions"     "$REPO/.config/fish/completions"     "completions/ symlink"
assert_symlink_to "$HOME/.config/fish/functions"       "$REPO/.config/fish/functions"       "functions/ symlink"
for f in 00-env.fish 10-colors.fish 20-mise.fish 25-prompt.fish \
         30-aliases.fish 35-abbreviations.fish 40-plugins.fish; do
  assert_symlink_to "$HOME/.config/fish/conf.d/$f" "$REPO/.config/fish/conf.d/$f" "conf.d/$f symlink"
done
assert_real_file  "$HOME/.config/fish/conf.d/15-local.fish"  "15-local.fish is a real file"
assert_real_file  "$HOME/.config/fish/conf.d/99-secrets.fish" "99-secrets.fish is a real file"

# No .template symlinks anywhere
for f in 15-local.fish.template 99-secrets.fish.template; do
  if [ -L "$HOME/.config/fish/conf.d/$f" ]; then
    record_fail "no .template symlink for $f" "found symlink: $HOME/.config/fish/conf.d/$f"
  else
    record_pass "no .template symlink for $f"
  fi
done

# Repo-side leak check
for f in 15-local.fish 99-secrets.fish fish_variables fish_history generated_completions; do
  assert_not_in_repo "$REPO/.config/fish/conf.d/$f" "no $f leaked under repo conf.d/"
  assert_not_in_repo "$REPO/.config/fish/$f"        "no $f leaked under repo fish/"
done

# ─── nvim ───────────────────────────────────
echo
echo "nvim layout"
echo "───────────"
assert_real_dir   "$HOME/.config/nvim"                                                "~/.config/nvim/ is a real dir"
assert_symlink_to "$HOME/.config/nvim/init.lua"        "$REPO/.config/nvim/init.lua"        "init.lua symlink"
assert_symlink_to "$HOME/.config/nvim/lazy-lock.json"  "$REPO/.config/nvim/lazy-lock.json"  "lazy-lock.json symlink"
assert_symlink_to "$HOME/.config/nvim/mason-lock.json" "$REPO/.config/nvim/mason-lock.json" "mason-lock.json symlink"
assert_symlink_to "$HOME/.config/nvim/lua"             "$REPO/.config/nvim/lua"             "lua/ symlink"
for f in lazy mason site lazyvim.json; do
  assert_not_in_repo "$REPO/.config/nvim/$f" "no $f leaked under repo nvim/"
done

# ─── worktrunk ──────────────────────────────
echo
echo "worktrunk layout"
echo "────────────────"
assert_real_dir   "$HOME/.config/worktrunk"                                            "~/.config/worktrunk/ is a real dir"
assert_symlink_to "$HOME/.config/worktrunk/config.toml" "$REPO/.config/worktrunk/config.toml" "config.toml symlink"
assert_not_in_repo "$REPO/.config/worktrunk/approvals.toml" "no approvals.toml leaked under repo worktrunk/"

# ─── summary ────────────────────────────────
echo
echo "───────────────────────────────────────"
echo "PASS: $pass    FAIL: $fail"
if [ "$fail" -gt 0 ]; then
  echo
  for msg in "${fail_msgs[@]}"; do
    printf '%s\n' "$msg"
  done
  exit 1
fi
