# Nothing rice chrome (Lane E / VEI-57)

Keeps the Glyph **black dotted field** coherent with Finder desktop icons.
Does **not** edit `launcher/*.swift` (Lanes A–D).

## Preference lock (permanent)

**Never mutate Dock apps / contents / tilesize / static-only.**  
`veil-rice apply`, theme apply (`wall_lock=glyph-field`), and `dock-nothing.sh` skip Dock writes entirely.  
Bar clearance around the Dock is OK (Lane C); rice Dock chrome is not.

## Commands

```bash
# Wallpaper + Finder desktop icons only (Dock skipped)
~/.config/veil/bin/veil-rice apply

# Pieces
~/.config/veil/tools/rice/desktop-icons.sh hide

# Undo Finder (wallpaper stays until theme change)
~/.config/veil/bin/veil-rice restore
```

`veil-theme apply nothing` runs chrome quietly when `wall_lock = "glyph-field"` —
wallpaper + Finder only; Dock untouched.

## Scenic-wall conflict

1. Wallpaper is always `art/nothing.jpg` (procedural dots + faint left-plane ring).
2. Regenerate with `python3 tools/make-nothing-wall.py` if missing.
3. `apply` re-pins that file even if a scenic wall was set manually.

## Finder icons

`CreateDesktop=false` hides icons on the desktop plane for screenshots.
Files remain in `~/Desktop` via Finder windows. Use `desktop-icons.sh show` to bring them back.
