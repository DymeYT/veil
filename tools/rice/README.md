# Nothing rice chrome (Lane E / VEI-57)

Keeps the Glyph **black dotted field** coherent with Dock + Finder chrome.
Does **not** edit `launcher/*.swift` (those belong to Lanes A–D).

## Commands

```bash
# Full Nothing session chrome (wall + Dock + desktop icons)
~/.config/veil/bin/veil-rice apply

# Pieces
~/.config/veil/tools/rice/dock-nothing.sh hide
~/.config/veil/tools/rice/desktop-icons.sh hide

# Undo Dock/Finder (wallpaper stays on art/nothing.jpg until you change themes)
~/.config/veil/bin/veil-rice restore
```

`veil-theme apply nothing` also runs chrome quietly when `wall_lock = "glyph-field"`
in `themes/nothing.toml` (default).

## Scenic-wall conflict

Scenic / Style walls fight Glyph surfaces. For Nothing:

1. Wallpaper is always `art/nothing.jpg` (procedural dots + faint left-plane ring).
2. Regenerate with `python3 tools/make-nothing-wall.py` if the file is missing.
3. `apply` re-pins that file even if a mountain/purple wall was set manually.

## Finder icons

`CreateDesktop=false` hides icons on the desktop plane for screenshots.
Files remain in `~/Desktop` via Finder windows. Use `desktop-icons.sh show` to bring them back.
