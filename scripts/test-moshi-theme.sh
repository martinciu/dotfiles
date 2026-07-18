#!/opt/homebrew/bin/bash
# Smoke test for the Moshi theme export pipeline: the committed
# .config/themes/moshi-<slug>.json artifacts (valid Moshi v1) and the
# moshi-theme fish function. CI-safe — needs neither Ghostty.app nor a
# phone, and never touches the real ~/.config (temp-HOME scaffold).
set -uo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

for tool in fish jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "⏭️  $tool not installed — skipping moshi-theme smoke"
    exit 0
  fi
done

pass=0
fail=0
fail_msgs=()
ok()  { pass=$((pass+1)); echo "  PASS  $1"; }
bad() { fail=$((fail+1)); fail_msgs+=("$1"); echo "  FAIL  $1"; }

SLUGS=(solarized mocha frappe dracula gruvbox tokyo-night nord latte rose-pine rose-pine-moon)

echo "— committed artifacts"
for slug in "${SLUGS[@]}"; do
  f="$DOTFILES/.config/themes/moshi-$slug.json"
  if [ ! -f "$f" ]; then
    bad "moshi-$slug.json exists"
    continue
  fi
  if jq -e '
      .v == 1
      and (.mode == "dark" or .mode == "light")
      and (.name | type == "string" and length > 0 and length <= 40)
      and (.colors | type == "object")
      and (.colors.background | type == "string" and test("^#[0-9a-f]{6}$"))
      and (.colors.foreground | type == "string" and test("^#[0-9a-f]{6}$"))
      and ([.colors[] | select(type != "string" or (test("^#[0-9a-f]{6}$") | not))] | length == 0)
      and ((.colors | keys) - ["background","foreground","cursor","black","red","green","yellow","blue","magenta","cyan","white","brightBlack","brightRed","brightGreen","brightYellow","brightBlue","brightMagenta","brightCyan","brightWhite","selectionBackground"] == [])
    ' "$f" >/dev/null 2>&1; then
    ok "moshi-$slug.json valid Moshi v1"
  else
    bad "moshi-$slug.json valid Moshi v1"
  fi
done

# Mode sanity: latte is the only light theme.
[ "$(jq -r .mode "$DOTFILES/.config/themes/moshi-latte.json" 2>/dev/null)" = "light" ] \
  && ok "latte mode=light" || bad "latte mode=light"
[ "$(jq -r .mode "$DOTFILES/.config/themes/moshi-solarized.json" 2>/dev/null)" = "dark" ] \
  && ok "solarized mode=dark" || bad "solarized mode=dark"

# Solarized repo override wins over the bundled palette (#93a1a1, not #002831).
[ "$(jq -r .colors.selectionBackground "$DOTFILES/.config/themes/moshi-solarized.json" 2>/dev/null)" = "#93a1a1" ] \
  && ok "solarized selection override applied" || bad "solarized selection override applied"

echo
echo "— moshi-theme function"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home/.config/themes" "$TMP/bin"
for slug in "${SLUGS[@]}"; do
  ln -s "$DOTFILES/.config/themes/moshi-$slug.json" "$TMP/home/.config/themes/moshi-$slug.json"
done
# Active theme = tokyo-night (relative symlink, exactly like theme-set's).
ln -s tokyo-night.tmux "$TMP/home/.config/themes/current.tmux"
# pbcopy stub: capture instead of clobbering the real clipboard.
printf '#!/bin/sh\ncat > "%s/clip"\n' "$TMP" > "$TMP/bin/pbcopy"
chmod +x "$TMP/bin/pbcopy"

run_fn() {  # run_fn <argv…> — moshi-theme in a scaffolded HOME
  HOME="$TMP/home" PATH="$TMP/bin:$PATH" fish -c "
    source $DOTFILES/.config/fish/functions/__theme_set_current.fish
    source $DOTFILES/.config/fish/functions/__theme_set_names.fish
    source $DOTFILES/.config/fish/functions/moshi-theme.fish
    moshi-theme $*"
}

out="$(run_fn solarized 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "explicit slug exits 0" || bad "explicit slug exits 0 (rc=$rc)"
grep -q 'moshi://theme?d=' <<<"$out" && ok "prints deep link" || bad "prints deep link"

b64="$(grep -o 'moshi://theme?d=[A-Za-z0-9+/=]*' <<<"$out" | head -1 | sed 's|.*d=||')"
name="$(printf '%s' "$b64" | base64 -d 2>/dev/null | jq -r .name 2>/dev/null)"
[ "$name" = "Solarized Dark" ] && ok "deep-link payload decodes (name)" || bad "deep-link payload decodes (got '$name')"

if [ -f "$TMP/clip" ] && grep -q '^moshi-theme:' "$TMP/clip"; then
  ok "clipboard string copied via pbcopy"
else
  bad "clipboard string copied via pbcopy"
fi
clip_name="$(sed 's/^moshi-theme://' "$TMP/clip" 2>/dev/null | base64 -d 2>/dev/null | jq -r .name 2>/dev/null)"
[ "$clip_name" = "Solarized Dark" ] && ok "clipboard payload decodes (name)" || bad "clipboard payload decodes (got '$clip_name')"

out="$(run_fn 2>&1)"; rc=$?
b64="$(grep -o 'moshi://theme?d=[A-Za-z0-9+/=]*' <<<"$out" | head -1 | sed 's|.*d=||')"
name="$(printf '%s' "$b64" | base64 -d 2>/dev/null | jq -r .name 2>/dev/null)"
[ "$rc" -eq 0 ] && [ "$name" = "Tokyo Night Storm" ] \
  && ok "no-arg resolves active theme (current.tmux)" || bad "no-arg resolves active theme (rc=$rc, got '$name')"

run_fn bogus-theme >/dev/null 2>&1 && bad "unknown slug rejected" || ok "unknown slug rejected"
run_fn --help >/dev/null 2>&1 && ok "--help exits 0" || bad "--help exits 0"

echo
echo "moshi-theme smoke: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  printf '  ❌ %s\n' "${fail_msgs[@]}"
  exit 1
fi
