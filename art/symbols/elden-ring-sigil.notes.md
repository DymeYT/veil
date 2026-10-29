# Elden Ring sigil — Guidance (elden-ring)

Mark for the Elden Ring environment "Guidance". Files: `elden-ring-sigil.json` (the launcher loads this), `elden-ring-sigil.svg`,
this note. viewBox 200x240, 15 even-odd contours.

## Why the logo sigil and not a Site of Grace
Every piece of official Elden Ring branding uses this sigil (the arcs and stem above the wordmark), so it is the game's own
identifier. A Site of Grace has no canonical flat emblem: in game it is a glowing particle effect. A drawn "grace" would be my
invention and would collapse into a generic glow or star at 30pt. The sigil's stem, two bows and cluster of circles stay distinct
at small sizes.

## Sources inspected (local copies in research/references/elden-ring/)
- Clean logo PNG taken from the official eldenring site, posted at https://i.redd.it/3e2afpjsi4f61.png
  (thread https://www.reddit.com/r/Eldenring/comments/lb5hlu/). This is the primary measurement reference (753x723 px).
- Key art with the sigil in the sky: https://i.redd.it/9oy8b1kalnfb1.jpg ; reveal and Great Rune comparison: https://i.redd.it/ruptolvqj1l81.jpg
- Fandom golden order render: https://static.wikia.nocookie.net/eldenring/images/2/27/ER_golden_order.png (page https://eldenring.fandom.com/wiki/Elden_Ring_(concept))
- Traced logo, for cross-checking only: https://www.freelogovectors.net/wp-content/uploads/2022/01/elden_ring_logo-freelogovectors.net_.png ;
  https://1000logos.net/elden-ring-logo/

## Geometry, measured from the official PNG with a circle Hough transform, residual maps and line probes (reference px)
- One vertical stem on axis x≈378.
- Four circles of equal radius (r≈92):
  - upper circle centred at (378,317)
  - middle circle at (378,361); its bottom arc, from about 54° to 126° (y-down), is missing in the logo, which is the "broken ring"
  - lower-left at (337,397) and lower-right at (419,397)
- Top bow: an arc of a circle centred at (378,−207), R≈319, opening upward, spanning ±33° about its lowest point. It is thickest at
  the middle, with fine tips, and has a bright knot where the stem crosses it at y≈112.
- Lower bow: an arc of a circle centred at (378,269), R≈323, spanning 40°–140°. Its centre sits exactly at the top of the middle
  circle (y 269), which is a nice internal relationship.
- The stem pierces the top bow and runs past the lower bow, fading to points at both ends.

## Construction (/tmp/marks/elden_ring.py)
- Reference px are mapped to the viewBox as (x−378)·0.38+100, (y−40)·0.38.
- Circles are 5.6-unit strokes. The gap in the middle circle has radial cuts.
- The bows are crescents with a sin^0.75 width profile (peak 7.5 and 7.0 units).
- The stem is 6.4 units wide with needle tapers.
- The knot is a small lozenge.
- Everything is unioned in shapely so the even-odd fill has no XOR holes where strokes cross, and circles keep more than 36 points
  per quarter.

## Simplifications
The logo's scratchy, burning texture, the cross-hatching and the stray sparks are removed. The faint outer tips of the lower bow are
cut back slightly (to 40°–140°) and the stem is shortened a little to keep the mark compact. All stroke weights are uniform.

## Verification
research/references/elden-ring/elden-ring-sigil-compare.png shows the reference, a 300px render, a 30px render at native size and
the 30px render enlarged 8x. The SVG was checked with Quick Look. At 30px the stem, both bows and the circle cluster are still
readable. The circles' interior detail merges at 1x, but the silhouette is unmistakably the Elden Ring logo.

No rights claimed; personal redraw for a private desktop theme. ELDEN RING © FromSoftware / Bandai Namco.
