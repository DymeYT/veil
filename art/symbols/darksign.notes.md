# Darksign — Cinder (dark-souls-3)

Mark for the Dark Souls III environment "Cinder". Files: `darksign.json` (the launcher loads this), `darksign.svg`, this note.
viewBox 200x200, 4 even-odd contours. The ring is centred at (100,106) with r=70.

## Why the Darksign
The other options were the coiled sword in the bonfire and the ash/ember motif of the DS3 logo. At about 30pt the coiled sword
turns into a thin vertical blade: its twisted coil, which is what makes it the coiled sword, would not show, so it would read as any
sword. The ash/ember logo motif has no fixed silhouette. The Darksign is a DS3 inventory item ("the sign of an accursed Undead")
and is also the eclipse that brands the sky in the Soul of Cinder ending. It is a closed, high-contrast form (a broken ring of fire
around a dark centre), so it stays recognisable at small sizes. It is specific, not a generic ring, because of where its flames and
breaks sit.

## Sources inspected (local copies in research/references/dark-souls-3/)
- DS3 Darksign item icon (in-game art): https://static0.fextralifeimages.com/file/darksouls3/a/a7/Darksign2.png
  from https://darksouls3.wiki.fextralife.com/Darksign (item text checked). This is the primary geometry reference.
- Fandom DS3 Darksign render: https://static.wikia.nocookie.net/darksouls/images/8/8a/Darksign_%28DSIII%29.png ,
  page https://darksouls.fandom.com/wiki/Darksign_(Dark_Souls_III)
- DS1 Darksign (for comparison only): https://static.wikia.nocookie.net/darksouls/images/4/4c/Darksign.png
- Soul of Cinder arena sky Darksign (screenshot): https://i.redd.it/5tk3khi73cpc1.jpeg

## Geometry read from the icon and the fandom render (they agree)
- A near-circular ring. The icon is about 7% wider than tall because of its perspective; I drew a true circle.
- The ring is broken, not continuous. Breaks sit at about 1 o'clock (the largest, between the top flame and the upper-right flame),
  about 9 o'clock (small), about 7–8 o'clock, and about 5–6 o'clock, where the ring passes behind the pedestal in the icon.
- Flame clusters sit at about 12 (slightly left of top), about 10 (the tallest, running up the left shoulder), about 2, about 6
  (rising into the dark centre), and a small one at about 4–5.
- flames on the upper arc rise upward; those on the right side lean outward with the ring, as drawn. This is the key detail that separates it from a sun or a
  generic flaming ring.

## Construction (/tmp/marks/darksign.py)
- The ring is a band whose width changes with angle: about 8.5 units normally, swelling to about 14 under each flame and tapering to
  a point at each break, like a brush stroke.
- Each flame tongue is built from a centreline (an upward rise with a slight sideways lean and an S-shaped sway) and a width profile
  that narrows from a full base to a fine tip. Tongues per cluster: top 3, upper-left 3, upper-right 2, bottom 3, lower-right 1.
- All parts are unioned with shapely and output as even-odd contours (about 47 points per quarter circle after a simplify
  tolerance of 0.008).

## Simplifications
The real image is painted fire, so the irregular flame streaks, sparks and glow became stylised tongues. The perspective ellipse
became a circle. The icon's pedestal is left out.

## Verification
Rendered at 300px and 30px next to the icon: research/references/dark-souls-3/darksign-compare.png.
The SVG was checked separately with Quick Look. At 30px it reads as a broken ring with upward flame points.

No rights claimed; personal redraw for a private desktop theme. Dark Souls III and the Darksign © FromSoftware / Bandai Namco.
