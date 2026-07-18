#!/usr/bin/env python3
"""Generate .config/themes/moshi-<slug>.json for every switchable theme.

Moshi (iPhone terminal) imports custom themes as v1 JSON: bg/fg/cursor +
16 ANSI colors + selectionBackground, hex-only, explicit dark/light mode.
The palettes come from Ghostty's bundled named themes — each repo
theme-<slug>.ghostty points at one via `theme = <Name>` — with any repo
hex overrides (e.g. solarized's selection-background) applied on top.
Artifacts are committed, so the everyday `moshi-theme` fish function
never needs Ghostty.app. Re-run after adding/altering a theme:

    python3 scripts/build-moshi-themes.py

Stdlib only. Requires Ghostty.app (reads its bundled theme files).
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
GHOSTTY_THEMES = "/Applications/Ghostty.app/Contents/Resources/ghostty/themes"

# Canonical switchable-theme slugs (mirror theme-set's __theme_set_names)
# → Moshi display name (≤ 40 chars, matches build-theme-colors.py THEMES).
THEMES = {
    "solarized":      "Solarized Dark",
    "mocha":          "Catppuccin Mocha",
    "frappe":         "Catppuccin Frappé",
    "dracula":        "Dracula",
    "gruvbox":        "Gruvbox",
    "tokyo-night":    "Tokyo Night Storm",
    "nord":           "Nord",
    "latte":          "Catppuccin Latte",
    "rose-pine":      "Rosé Pine",
    "rose-pine-moon": "Rosé Pine Moon",
}

# Moshi ANSI field names, palette index order 0–15.
ANSI = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
        "brightBlack", "brightRed", "brightGreen", "brightYellow",
        "brightBlue", "brightMagenta", "brightCyan", "brightWhite"]

HEX = r'(#[0-9a-fA-F]{6})\b'

def parse_ghostty(text):
    """Ghostty config lines → {'theme': str?, 'palette': {int: '#hex'},
    '<key>': '#hex'}. Comment lines start with '#' at col 0 only — hex
    values also contain '#', so no inline comment stripping."""
    out = {"palette": {}}
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        m = re.match(r'palette\s*=\s*(\d+)\s*=\s*' + HEX, s)
        if m:
            out["palette"][int(m.group(1))] = m.group(2).lower()
            continue
        m = re.match(r'theme\s*=\s*(.+)$', s)
        if m:
            out["theme"] = m.group(1).strip()
            continue
        m = re.match(r'([\w-]+)\s*=\s*' + HEX, s)
        if m:
            out[m.group(1)] = m.group(2).lower()
    return out

def lum(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def build(slug, name):
    repo_path = f".config/ghostty/theme-{slug}.ghostty"
    with open(repo_path, encoding="utf-8") as f:
        repo = parse_ghostty(f.read())
    bundled_name = repo.get("theme")
    if not bundled_name:
        sys.exit(f"error: no `theme = <Name>` line in {repo_path}")
    bundled_path = os.path.join(GHOSTTY_THEMES, bundled_name)
    if not os.path.exists(bundled_path):
        sys.exit(f"error: bundled theme not found: {bundled_path}")
    with open(bundled_path, encoding="utf-8") as f:
        base = parse_ghostty(f.read())
    # Repo overrides win over bundled values (e.g. solarized selection).
    merged = {**base,
              **{k: v for k, v in repo.items() if k not in ("theme", "palette")}}
    pal = base["palette"]
    missing = [k for k in ("background", "foreground") if k not in merged]
    missing += [f"palette {n}" for n in range(16) if n not in pal]
    if missing:
        sys.exit(f"error: {bundled_name}: missing {', '.join(missing)}")
    colors = {"background": merged["background"],
              "foreground": merged["foreground"]}
    if "cursor-color" in merged:
        colors["cursor"] = merged["cursor-color"]
    for n, key in enumerate(ANSI):
        colors[key] = pal[n]
    if "selection-background" in merged:
        colors["selectionBackground"] = merged["selection-background"]
    # No Moshi field exists for selection-foreground / cursor-text — dropped.
    return {
        "v": 1,
        "name": name,
        "mode": "light" if lum(merged["background"]) > 0.5 else "dark",
        "colors": colors,
    }

if __name__ == "__main__":
    if not os.path.isdir(GHOSTTY_THEMES):
        sys.exit(f"error: {GHOSTTY_THEMES} not found — Ghostty.app is required "
                 "to (re)generate; the committed moshi-*.json artifacts keep "
                 "`moshi-theme` working without it")
    for slug, name in THEMES.items():
        theme = build(slug, name)
        out = f".config/themes/moshi-{slug}.json"
        with open(out, "w", encoding="utf-8") as f:
            json.dump(theme, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"wrote {out}  ({theme['mode']}, {len(theme['colors'])} colors)")
