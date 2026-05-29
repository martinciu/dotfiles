#!/usr/bin/env python3
"""Generate docs/theme-colors.html — every distinct color in each switchable
theme, labelled with the variable/role name it's bound to across all themed
tools (tmux, starship, lnav, btop, eza, ghostty, delta, glow, gh-dash,
lazygit). Each theme card is painted in that theme's real terminal background
and foreground.

Reads the per-theme config files straight from the repo, so re-run after
adding/altering a theme:  python3 scripts/build-theme-colors.py
Stdlib only; no third-party deps.
"""
import json, re, os, colorsys, html

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
OUT = os.path.join(ROOT, "docs", "theme-colors.html")

HEXSTR = r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b'
HEX = re.compile(HEXSTR)
GENERIC = {"color","background_color","background","foreground","fg","bg","value"}

def hx(s): return s.lower()

# ---------- per-format extractors -> list of (hex, name) ----------
def extract_tmux(text):
    out=[]
    for line in text.splitlines():
        m = re.search(r'@color_(\S+)\s+"?(' + HEXSTR + ')"?', line)
        if m: out.append((hx(m.group(2)), m.group(1)))
    return out

def extract_starship(text):
    out=[]
    for line in text.splitlines():
        m = re.match(r'\s*([A-Za-z0-9_]+)\s*=\s*"(' + HEXSTR + ')"', line)
        if m: out.append((hx(m.group(2)), m.group(1)))
    return out

def extract_btop(text):
    out=[]
    for line in text.splitlines():
        m = re.search(r'theme\[(\w+)\]\s*=\s*"(' + HEXSTR + ')"', line)
        if m: out.append((hx(m.group(2)), m.group(1)))
    return out

def extract_ghostty(text):
    out=[]
    for line in text.splitlines():
        m = re.match(r'\s*palette\s*=\s*(\d+)\s*=\s*(' + HEXSTR + ')', line)
        if m: out.append((hx(m.group(2)), f"ansi {m.group(1)}")); continue
        m = re.match(r'\s*([\w-]+)\s*=\s*(' + HEXSTR + ')', line)
        if m: out.append((hx(m.group(2)), m.group(1)))
    return out

def extract_tealdeer(text):
    # tealdeer 1.8 rejects "#hex"; colors are RGB tables under [style.<role>]:
    #   [style.command_name]
    #   foreground = { rgb = { r = 108, g = 113, b = 196 } }
    out=[]; role=None
    for line in text.splitlines():
        s=line.strip()
        m=re.match(r'\[style\.([\w]+)\]', s)
        if m: role=m.group(1); continue
        mm=re.search(r'\br\s*=\s*(\d+),\s*g\s*=\s*(\d+),\s*b\s*=\s*(\d+)', s)
        if role and mm:
            r,g,b=(int(x) for x in mm.groups())
            out.append(("#%02x%02x%02x"%(r,g,b), role))
    return out

def extract_gitconfig(text):
    out=[]
    for line in text.splitlines():
        m = re.match(r'\s*([\w-]+)\s*=\s*(.*)$', line)
        if not m: continue
        key, val = m.group(1), m.group(2)
        for h in HEX.findall(val): out.append((hx(h), key))
    return out

def extract_yaml(text):
    out=[]; stack=[]  # (indent, key)
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith('#'): continue
        indent = len(raw) - len(raw.lstrip(' '))
        line = raw.strip()
        while stack and stack[-1][0] >= indent: stack.pop()
        if line.startswith('- '):
            val = line[2:]
            name = stack[-1][1] if stack else '?'
            for h in HEX.findall(val): out.append((hx(h), name))
            continue
        m = re.match(r'(["\']?[\w.-]+["\']?):\s*(.*)$', line)
        if not m: continue
        key = m.group(1).strip('"\''); val = m.group(2)
        hxs = HEX.findall(val)
        if hxs:
            for h in hxs: out.append((hx(h), key))
        else:
            stack.append((indent, key))
    return out

def extract_json(obj, parent, out):
    if isinstance(obj, dict):
        for k,v in obj.items():
            if isinstance(v, str) and re.fullmatch(HEXSTR, v):
                name = parent if k in GENERIC and parent else k
                out.append((hx(v), name))
            else:
                extract_json(v, k, out)
    elif isinstance(obj, list):
        for it in obj:
            if isinstance(it, str) and re.fullmatch(HEXSTR, it):
                out.append((hx(it), parent or '?'))
            else:
                extract_json(it, parent, out)

def from_file(path, fn):
    if not os.path.exists(path): return None
    with open(path, encoding="utf-8", errors="replace") as f:
        return fn(f.read())

def json_file(path):
    if not os.path.exists(path): return None
    with open(path, encoding="utf-8", errors="replace") as f:
        out=[]; extract_json(json.load(f), None, out); return out

def lnav_file(path, key):
    if not os.path.exists(path): return None
    with open(path, encoding="utf-8", errors="replace") as f:
        defs = json.load(f).get("ui",{}).get("theme-defs",{})
    if key not in defs: return None
    out=[]; extract_json(defs[key], key, out); return out

THEMES = {
    "Solarized Dark":"solarized","Catppuccin Mocha":"mocha","Catppuccin Frappé":"frappe",
    "Catppuccin Latte":"latte","Dracula":"dracula","Gruvbox":"gruvbox",
    "Tokyo Night Storm":"tokyo-night","Nord":"nord","Rosé Pine":"rose-pine","Rosé Pine Moon":"rose-pine-moon",
}
# Actual terminal background / foreground per theme, read once from Ghostty's
# bundled theme files (the named themes the repo's theme-<slug>.ghostty files
# reference, e.g. "Solarized Dark Patched", "Catppuccin Mocha"). Hardcoded so
# this generator stays portable (no dependency on Ghostty.app being present).
BG = {
    "solarized":      ("#001e27","#708284"),
    "mocha":          ("#1e1e2e","#cdd6f4"),
    "frappe":         ("#303446","#c6d0f5"),
    "latte":          ("#eff1f5","#4c4f69"),
    "dracula":        ("#282a36","#f8f8f2"),
    "gruvbox":        ("#282828","#ebdbb2"),
    "tokyo-night":    ("#24283b","#c0caf5"),
    "nord":           ("#2e3440","#d8dee9"),
    "rose-pine":      ("#191724","#e0def4"),
    "rose-pine-moon": ("#232136","#e0def4"),
}
BTOP = {"mocha":"catppuccin_mocha","frappe":"catppuccin_frappe","latte":"catppuccin_latte",
        "rose-pine":"rose-pine","rose-pine-moon":"rose-pine-moon"}
LNAV = {"mocha":("catppuccin.json","catppuccin-mocha"),"frappe":("catppuccin.json","catppuccin-frappe"),
        "gruvbox":("gruvbox.json","gruvbox-dark"),"tokyo-night":("tokyo-night.json","tokyo-night"),
        "nord":("nord.json","nord"),"rose-pine":("rose-pine.json","rose-pine"),
        "rose-pine-moon":("rose-pine.json","rose-pine-moon")}
TOOLS = ["tmux","starship","lnav","btop","eza","ghostty","delta","glow","gh-dash","lazygit","tealdeer"]

def pairs_for(slug):
    p = {}
    p["tmux"]     = from_file(f".config/themes/{slug}.tmux", extract_tmux)
    p["starship"] = from_file(f".config/starship-{slug}.toml", extract_starship)
    p["btop"]     = from_file(f".config/btop/themes/{BTOP[slug]}.theme", extract_btop) if slug in BTOP else None
    p["eza"]      = from_file(f".config/eza/eza-{slug}.yml", extract_yaml)
    p["ghostty"]  = from_file(f".config/ghostty/theme-{slug}.ghostty", extract_ghostty)
    p["delta"]    = from_file(f".config/themes/delta-{slug}.gitconfig", extract_gitconfig)
    p["glow"]     = json_file(f".config/glow/glamour-{slug}.json")
    p["gh-dash"]  = from_file(f".config/gh-dash/theme-colors-{slug}.yml", extract_yaml)
    p["lazygit"]  = from_file(f".config/lazygit/theme-colors-{slug}.yml", extract_yaml)
    p["tealdeer"] = from_file(f".config/tealdeer/config-{slug}.toml", extract_tealdeer)
    if slug in LNAV:
        fn,key = LNAV[slug]; p["lnav"] = lnav_file(f".config/lnav/configs/installed/{fn}", key)
    else:
        p["lnav"] = None
    return p

def to_rgb(h):
    h=h.lstrip("#")
    if len(h)==3: h="".join(c*2 for c in h)
    h=h[:6]
    return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
def lum(h):
    r,g,b=to_rgb(h); return 0.2126*r+0.7152*g+0.0722*b
def sortkey(h):
    r,g,b=to_rgb(h); hh,ll,ss=colorsys.rgb_to_hls(r,g,b)
    return (0,0,ll) if ss<0.12 else (1,round(hh*24),ll)

if __name__ == "__main__":
    import sys
    # build per theme: hexmap hex -> list of (name, tool), preserving order, deduped
    themes_data=[]; grand=set()
    for name, slug in THEMES.items():
        p = pairs_for(slug)
        hexmap={}  # hex -> list[(name,tool)]
        seen=set()
        for t in TOOLS:
            if not p[t]: continue
            for h,nm in p[t]:
                grand.add(h)
                key=(h,nm,t)
                if key in seen: continue
                seen.add(key)
                hexmap.setdefault(h,[]).append((nm,t))
        cols=sorted(hexmap.keys(), key=sortkey)
        themes_data.append((name, slug, cols, hexmap))

    if "--dump" in sys.argv:
        for name, slug, cols, hexmap in themes_data:
            print(f"\n### {name} ({len(cols)} colors)")
            for c in cols:
                names="; ".join(f"{n} [{t}]" for n,t in hexmap[c])
                print(f"  {c}  {names}")
        sys.exit(0)

    # ---- render ----
    def item(h, nm_list):
        names=[]
        seen=set()
        for n,t in nm_list:
            if n not in seen: seen.add(n); names.append(n)
        title = " · ".join(f"{n} ({t})" for n,t in nm_list)
        shown = names[:2]
        more = len(names)-len(shown)
        label = ", ".join(html.escape(x) for x in shown)
        if more>0: label += f' <span class="more">+{more}</span>'
        return (f'<div class="sw" title="{html.escape(title)}" '
                f'onclick="navigator.clipboard&&navigator.clipboard.writeText(\'{h}\')">'
                f'<div class="chip" style="background:{h}"></div>'
                f'<div class="meta"><div class="names">{label}</div>'
                f'<div class="hx">{h}</div></div></div>')

    cards=[]
    for name, slug, cols, hexmap in themes_data:
        items="".join(item(c, hexmap[c]) for c in cols)
        bg, fg = BG[slug]
        light = lum(bg) > 0.5
        tile  = "rgba(0,0,0,.05)"  if light else "rgba(255,255,255,.05)"
        tileb = "rgba(0,0,0,.16)"  if light else "rgba(255,255,255,.16)"
        style = (f"background:{bg};color:{fg};border-color:{tileb};"
                 f"--fg:{fg};--tile:{tile};--tileb:{tileb};")
        cards.append(f'''<section class="card" style="{style}">
      <header><h2>{html.escape(name)}</h2><span class="count">{len(cols)} colors · bg {bg}</span></header>
      <div class="grid">{items}</div>
    </section>''')

    page=f'''<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>dotfiles — theme colors</title>
<style>
  :root {{ color-scheme: dark; }}
  *{{box-sizing:border-box;}}
  body{{margin:0;font:14px/1.4 -apple-system,"SF Pro Text",Segoe UI,Roboto,sans-serif;
        background:#0d1117;color:#c9d1d9;padding:32px;}}
  h1{{font-size:22px;margin:0 0 4px;}}
  .sub{{color:#8b949e;margin:0 0 28px;font-size:13px;max-width:900px;}}
  .sub b{{color:#c9d1d9;}}
  .cards{{display:grid;gap:22px;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));}}
  .card{{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:16px 16px 18px;
        box-shadow:0 1px 0 rgba(0,0,0,.3);}}
  .card header{{display:flex;align-items:baseline;justify-content:space-between;gap:8px;margin-bottom:12px;}}
  .card h2{{font-size:16px;margin:0;color:var(--fg);}}
  .count{{color:var(--fg);opacity:.6;font-size:12px;font-variant-numeric:tabular-nums;}}
  .grid{{display:grid;gap:8px;grid-template-columns:repeat(auto-fill,minmax(108px,1fr));}}
  .sw{{border:1px solid var(--tileb);border-radius:8px;overflow:hidden;cursor:pointer;
       background:var(--tile);transition:transform .08s;}}
  .sw:hover{{transform:scale(1.04);border-color:#58a6ff;}}
  .chip{{height:40px;border-bottom:1px solid var(--tileb);}}
  .meta{{padding:5px 7px 6px;}}
  .names{{font-size:11px;line-height:1.25;color:var(--fg);word-break:break-word;}}
  .more{{color:var(--fg);opacity:.5;}}
  .hx{{font:10px/1 ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--fg);opacity:.6;margin-top:3px;}}
  footer{{color:#6e7681;font-size:12px;margin-top:32px;max-width:900px;}}
</style></head><body>
  <h1>dotfiles theme colors — named by function</h1>
  <p class="sub">Each distinct hex per theme, labelled with the variable / role name it's bound to in the
     config. Sources: {" · ".join(TOOLS)}. A color often has several names across tools
     (e.g. <code>blue</code> in starship, <code>accent_blue</code> in tmux, <code>directory</code> in eza) —
     hover a swatch for the full list with its tool; click to copy the hex.
     <b>{len(grand)}</b> distinct colors total.</p>
  <div class="cards">{"".join(cards)}</div>
  <footer>Generated by <code>scripts/build-theme-colors.py</code>. Names are the keys/roles defined in each
     tool's theme file: palette names (tmux <code>@color_*</code>, starship/lnav palette vars, btop
     <code>theme[*]</code>) and usage roles (eza filekinds, glow elements, gh-dash/lazygit UI keys, delta
     styles, ghostty <code>ansi N</code> / selection, tealdeer tldr roles). Solarized &amp; Dracula have no lnav/btop entries
     (built-in there). Each card is painted in that theme's real terminal background &amp; foreground,
     read from Ghostty's bundled theme files.</footer>
</body></html>'''
    with open(OUT,"w") as f: f.write(page)
    print(f"wrote {os.path.relpath(OUT, ROOT)}  ({len(grand)} distinct colors)")
