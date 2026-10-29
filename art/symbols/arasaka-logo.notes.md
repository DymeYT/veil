# arasaka-logo: Arasaka Corporation insignia (Cyberpunk 2077)

## Sources
- Cyberpunk Wiki file `Arasaka_Logo_CP2077.png` (1920x1080 horizontal lockup, uploaded April 2020, used as the wiki's lead image):
  https://static.wikia.nocookie.net/cyberpunk/images/5/5f/Arasaka_Logo_CP2077.png/revision/latest?cb=20200408033100
  (page: https://cyberpunk.fandom.com/wiki/Arasaka). Local copy: `research/references/arasaka/fandom-arasaka-logo-cp2077.webp`.
- Wikimedia Commons `Arasaka_logo_lite.png`: https://commons.wikimedia.org/wiki/File:Arasaka_logo_lite.png (cross-check).
- r/cyberpunkgame "original vs clean-up" comparison: https://i.redd.it/umxilvfnbxt51.jpg (cross-check).

## What I inspected
I extracted the emblem's alpha mask from the wiki file and measured it by pixel runs (ring outer radius 105.5px).
The Commons redraw and the Reddit original/clean-up show the same construction.

## Geometry (ring outer radius R = 100 units, centre at (102,102), viewBox 204x204)
- Ring: outer 100, thickness 13.0 (measured 13.75/105.5).
- Three equal disks, r = 27.7: top at (0,-37.4), sides at (+/-50.0,-4.3).
- Stem: width 16.1, runs from the top disk to y = +76.3, with a flat end. It stops short of the ring (gap of about 10.7 units), as in the source.
- Arms: the same width as the stem, at exactly 45 degrees. Each centreline meets the axis at y = +40 and runs up into its side disk. As measured, an arm does not point at its disk's centre: it sits about 6 units inboard.
- I traced the union with an SDF and marching squares (900-cell grid) and simplified it to a tolerance of 0.04 units. The result is 3 contours: the ring outside, the ring inside and the tree figure.

## Simplifications
None in the emblem itself. I left out the wordmark. A source asymmetry of about 2px between the ring centre and the stem axis is normalised to perfect symmetry.

## Verification
I rendered the mark at 300px and at 29px (the launcher frame) beside the reference: `research/references/arasaka/comparison-arasaka-logo.png`.
At 29px the ring, the three disks and the Y stem all stay distinct. Quick Look renders the SVG identically.

No rights claimed; personal redraw. Arasaka and Cyberpunk 2077 are trademarks of CD PROJEKT S.A.
