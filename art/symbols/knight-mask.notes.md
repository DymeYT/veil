# knight-mask (Hallownest / Hollow Knight)

Files: knight-mask.json (launcher), knight-mask.svg (same geometry, one path, evenodd, currentColor).
viewBox 278.84 x 300. 3 contours: mask silhouette plus two eye holes (evenodd cuts).

## Sources inspected (local copies in research/references/hallownest/)
- Official hand-drawn Knight art: https://static.wikia.nocookie.net/p__/images/4/4c/HK_Knight.png (page https://hero.fandom.com/wiki/The_Knight_(Hollow_Knight)), 1359x1407. The outline was overlaid directly on this art to calibrate the horns (see below).
- Front-facing in-game sprite: https://static.wikia.nocookie.net/hollowknight/images/0/06/The_Knight_Front.png (page https://hollowknight.fandom.com/wiki/Knight). Used for symmetric front proportions, because the large art is slightly three-quarter.

## Why the mask and not the Pale King / Hallownest crest
The Knight's two-horned mask is the series' universal identifier: box art, store icon and every piece of merch. The crest is lore-deep but much less recognisable, and at 30pt it would reduce to an ornament. The mask also has a strong, simple silhouette with two eye holes, which survives at small sizes.

## Geometry (head width = 438 units)
- Head: a near-rectangle about 0.98 as tall as it is wide. The sides are almost vertical and narrow slightly toward the rounded jaw. The top is a faint arch.
- Horns: one per side, mirror-symmetric. They rise from the head's top corners, bow outward to their widest point (about 0.25 of head width beyond the cheek), then curve back up and in to a tip that points up and inward. Horn width is about 0.18 of head width. The tips rise about 0.64 of the head height above the brow.
- Each horn tip carries the notch from the official art: a V cut into the inner edge just below the tip, which leaves a small inward barb.
- Eyes: two upright ovals (0.29 wide x 0.34 tall relative to head width), centred at 0.69 of the head height and spaced 0.47 head widths apart, with a 3 degree inward tilt.
- Outline calibration: the left half was overlaid on HK_Knight.png and matches the outer horn edge, the notch position and the hollow between the horns. The right half is mirrored, which removes the art's perspective.

## Simplifications
- The black ink outline, the cloak and the shading are dropped. The silhouette edge sits at the outer edge of the white mask. Hand-drawn wobble is smoothed into Bezier curves, and the mask is made exactly symmetric.

## Verification
Rendered via QuickLook at 30, 60 and 300px tall. Comparison: research/references/hallownest/knight-mask-comparison.png. Reads clearly at 30px (eyes about 6px, horns about 2px thick).

No rights claimed; personal redraw for a private desktop theme. Hollow Knight is (c) Team Cherry.
