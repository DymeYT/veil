# factorio-gear: the gear of the Factorio logo / iron gear wheel item

## Sources
- Steam logo asset (official wordmark, which ends in the gear): https://cdn.cloudflare.steamstatic.com/steam/apps/427520/logo.png
  Local copy: `research/references/factorio/steam-logo.png`.
- Official Factorio Wiki, Iron gear wheel item icon: https://wiki.factorio.com/Iron_gear_wheel
  (image https://wiki.factorio.com/images/Iron_gear_wheel.png). Local copy: `wiki-iron-gear-wheel.png`.
- A top-down 4K fan render of the item, used only to measure proportions: https://www.reddit.com/r/factorio/comments/pv32nf/ (`reddit-4k-gear.png`).

## What I inspected
I magnified the logo gear 4x. The logo gear and the item icon are the same object: **8 teeth** spaced 45 degrees apart; blocky, parallel-sided teeth with flat tops; a raised annular hub; and a large through-bore.
The logo is in 3/4 perspective, so I took ratios from its horizontal axis (which is true scale) and cross-checked them on the top-down render.

## Geometry (tooth-tip radius 100, centre (102,102), viewBox 204x204)
- Tip radius 100, root radius 79, tooth width 28 with parallel flanks. Tooth 0 points straight up.
- Hub step drawn as a 5-unit groove centred at r = 70 (logo: raised ring outer edge at 0.70).
- Bore radius 35 (logo: 0.347).
- Tooth corners have a 2.5-unit radius and the roots a 5-unit smooth-min fillet. These are restrained softenings for craft; the silhouette stays blocky like the source.
- Traced by SDF and marching squares into 4 even-odd contours: the gear outline, the two edges of the groove, and the bore.

## Simplifications
I flattened the 3D bevel, perspective and texture into a single-colour silhouette. I chose the groove as the flat way to express the raised hub ring.

## Verification
Renders at 300px and 29px beside the logo gear: `research/references/factorio/comparison-factorio-gear.png`.
At 29px all 8 teeth and the bore stay clear, and the hub groove reads as a faint inner ring.

No rights claimed; personal redraw. Factorio is a trademark of Wube Software Ltd.
