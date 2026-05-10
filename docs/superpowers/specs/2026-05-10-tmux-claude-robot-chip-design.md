# tmux Claude Usage Chip — Robot Glyph Design

## Summary

Add a robot glyph (`nf-fa-robot`) as a new leftmost chip in the tmux status bar's Claude usage cluster (5h + 7d chips).

## Visual Layout

```
[bar_bg] ← [robot] → [5h] → [7d] → [bar_bg]
```

Arrows:
- Robot left cap: `tri_l` (points left to bar_bg)
- All other caps: `tri_r` (forward-pointing)

## Colors (Solarized base16)

| Chip | Background | Foreground |
|------|------------|------------|
| Robot | cyan (`#2aa198`) | base2 (`#fdf6e3`) |
| 5h | violet (`#6c71c4`) | base2 (`#fdf6e3`) |
| 7d | yellow (`#b58900`) | base02 (`#073642`) |

## Glyphs

- Robot: `nf-fa-robot` (U+F544) → UTF-8 `\xef\x95\x84`
- Hourglass: `nf-fa-hourglass-half` (U+F252) → `\xee\x82\xb6`
- Calendar: `nf-oct-calendar` (U+F455) → `\xef\x91\x95`
- Left cap: `tri_l` (U+E0B6) → `\xee\x82\xb6`
- Right cap: `tri_r` (U+E0B4) → `\xee\x82\xb4`

## Implementation

- Script: `.config/tmux/bin/tmux-claude-usage`
- Add robot chip to the rendering pipeline
- Use `tri_r` for all caps except robot left cap (`tri_l`)
- Atomic hide preserved: robot + 5h + 7d all hide when ccpulse unavailable

## Testing

- Run smoke tests: `./scripts/test-tmux-claude-usage.sh`
- Visual verification in tmux

## Acceptance Criteria

1. Robot chip appears left of 5h chip
2. Arrow direction: bar ← robot → 5h → 7d → bar
3. Robot chip shares atomic hide behavior with 5h/7d
4. All smoke tests pass