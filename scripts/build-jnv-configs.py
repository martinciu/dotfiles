#!/usr/bin/env python3
"""Generate .config/jnv/config-<slug>.toml for every switchable theme.

jnv needs a COMPLETE config (its top-level Config struct has no serde defaults,
and the [keybinds] blocks are mandatory), and its color keys live inside nested
tables — so neither tealdeer's partial-file nor gh-dash's cat-concat approach
works. Instead we template jnv's full default config, swapping only the color
lines, using each theme's tmux @color_* palette as the source of truth (same
palette build-theme-colors.py reads). Re-run after adding/altering a theme:

    python3 scripts/build-jnv-configs.py

Stdlib only. Requires Python 3.11+ for tomllib (validation).
"""
import os, re, sys, tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
OUT_DIR = os.path.join(ROOT, ".config", "jnv")

# Canonical switchable-theme slugs (mirror theme-set's __theme_set_names).
THEMES = ["solarized", "mocha", "frappe", "dracula", "gruvbox",
          "tokyo-night", "nord", "latte", "rose-pine", "rose-pine-moon"]

def palette(slug):
    """Read .config/themes/<slug>.tmux → {role: '#hex'} from @color_<role> lines."""
    path = os.path.join(ROOT, ".config", "themes", f"{slug}.tmux")
    pal = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.search(r'@color_(\S+)\s+"?(#[0-9a-fA-F]{6})"?', line)
            if m:
                pal[m.group(1)] = m.group(2).lower()
    return pal

def styles(p):
    """Map jnv style tokens → termcfg notation strings, from a tmux palette p.
    Roles match fx's ANSI semantics so jnv + fx look consistent."""
    blue, green, cyan = p["accent_blue"], p["accent_green"], p["accent_cyan"]
    magenta, yellow   = p["accent_magenta"], p["accent_yellow"]
    muted, deep       = p["muted_fg"], p["deep_bg"]
    return {
        "KEY":               f"fg={blue},attr=bold",
        "STRING":            f"fg={green}",
        "NUMBER":            f"fg={cyan}",
        "BOOLEAN":           f"fg={magenta}",
        "NULL":              f"fg={muted}",
        "EDITOR_PREFIX":     f"fg={blue}",
        "EDITOR_PREFIX_DIM": f"fg={blue},attr=dim",
        "EDITOR_CURSOR":     f"bg={magenta}",
        "COMPL_ACTIVE":      f"fg={deep},bg={yellow}",
        "COMPL_INACTIVE":    f"fg={muted}",
    }

# jnv's complete default.toml, with the color lines tokenized as {{TOKEN}}.
# Everything else (keybinds, reactivity, indents, prefixes) is verbatim default.
BASE = '''# Whether to hide hint messages
no_hint = false

# Editor settings
# Uses promkit_widgets::text_editor::Config directly
[editor.on_focus]
edit_mode = "Insert"
word_break_chars = [".", "|", "(", ")", "[", "]"]
prefix = "❯❯ "
prefix_style = "{{EDITOR_PREFIX}}"
active_char_style = "{{EDITOR_CURSOR}}"
inactive_char_style = ""

# Theme settings when the editor is unfocused
[editor.on_defocus]
prefix = "▼ "
prefix_style = "{{EDITOR_PREFIX_DIM}}"
active_char_style = "attr=dim"
inactive_char_style = "attr=dim"

# JSON display settings
[json]
# max_streams =

# JSON display settings
# Uses promkit_widgets::jsonstream::Config directly
[json.stream]
indent = 2
curly_brackets_style = "attr=bold"
square_brackets_style = "attr=bold"
key_style = "{{KEY}}"
string_value_style = "{{STRING}}"
number_value_style = "{{NUMBER}}"
boolean_value_style = "{{BOOLEAN}}"
null_value_style = "{{NULL}}"
active_item_attribute = "bold"
inactive_item_attribute = "dim"
overflow_mode = "Wrap"

# Completion feature settings
[completion]
search_result_chunk_size = 100
search_load_chunk_size = 50000

# Completion UI settings
# Uses promkit_widgets::listbox::Config directly
[completion.listbox]
lines = 3
cursor = "❯ "
active_item_style = "{{COMPL_ACTIVE}}"
inactive_item_style = "{{COMPL_INACTIVE}}"

# Keybinding settings
[keybinds]
exit = ["Ctrl+C"]
copy_query = ["Ctrl+Q"]
copy_result = ["Ctrl+O"]
switch_mode = ["Shift+Down", "Shift+Up"]

# Keybindings for editor operations
[keybinds.on_editor]
backward = ["Left"]
forward = ["Right"]
move_to_head = ["Ctrl+A"]
move_to_tail = ["Ctrl+E"]
move_to_previous_nearest = ["Alt+B"]
move_to_next_nearest = ["Alt+F"]
erase = ["Backspace"]
erase_all = ["Ctrl+U"]
erase_to_previous_nearest = ["Ctrl+W"]
erase_to_next_nearest = ["Alt+D"]
completion = ["Tab"]
on_completion.up = ["Up"]
on_completion.down = ["Down", "Tab"]

# Keybindings for JSON viewer operations
[keybinds.on_json_viewer]
up = ["Up", "Ctrl+K", "ScrollUp"]
down = ["Down", "Ctrl+J", "ScrollDown"]
move_to_head = ["Ctrl+L"]
move_to_tail = ["Ctrl+H"]
toggle = ["Enter"]
expand = ["Ctrl+P"]
collapse = ["Ctrl+N"]

# Application reactivity settings
[reactivity_control]
query_debounce_duration = "600ms"
resize_debounce_duration = "200ms"
spin_duration = "300ms"
'''

def render(slug):
    out = BASE
    for tok, val in styles(palette(slug)).items():
        out = out.replace("{{" + tok + "}}", val)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}", out)
    if leftover:
        raise SystemExit(f"{slug}: unsubstituted tokens {leftover}")
    tomllib.loads(out)  # fail loudly on invalid TOML
    return out

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for slug in THEMES:
        text = render(slug)
        with open(os.path.join(OUT_DIR, f"config-{slug}.toml"), "w", encoding="utf-8") as f:
            f.write(text)
        print(f"wrote .config/jnv/config-{slug}.toml")
