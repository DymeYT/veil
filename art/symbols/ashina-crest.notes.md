# Ashina crest — Ashina (sekiro)

Mark for the Sekiro environment "Ashina". Files: `ashina-crest.json` (the launcher loads this), `ashina-crest.svg`, this note.
viewBox 200x200, 17 even-odd contours.

## Verification that the crest exists, and why not 忍
The Ashina clan crest is real in-game iconography. It is a Japanese iris (shōbu, a pun on 尚武 "martial spirit" and 勝負 "contest")
inside a ring of iris leaves. The game's mon is the game's own design; the historical Ashina clan's mon is a different design
(maru ni mitsubiki-ryō, per Wikipedia), so I did not use it. Evidence:
- It is printed in the official *Sekiro: Shadows Die Twice Collectible Artbook* (FromSoftware), behind the CONTENTS page:
  https://i.imgur.com/KvvV8wA.jpg (thread https://www.reddit.com/r/Sekiro/comments/k80auz/ashina_clan_symbol/)
- It appears in gold on the back of Isshin Ashina's coat in official concept art: https://i.redd.it/nl8abf4lcm361.jpg
- Shetani's Lair describes "Ashina armor with their Japanese Iris on the chest and on the back":
  https://shetanislair.com/en/posts/the-world-of-sekiro-ashina-castle
- r/Sekiro identifies the iris and the shōbu pun: https://www.reddit.com/r/Sekiro/comments/x19cnw/what_is_exactly_the_symbol_on_the_ashina_crest/
- Clean flat version used for measurement: https://i.redd.it/y53oxgnr0sk91.jpg (1475x1401). It is a fan-cleaned version, but I checked
  it element by element against the artbook page: same ring, same flower, same stems.
I found nothing establishing 忍 as an official Sekiro identifier, so the kanji is not used.

## Geometry (measured in a 1000x950 frame from row and column black-run probes; mirror-symmetric about x=500)
- Ring of leaves. Each half is concentric about a centre offset 5 units outward (left half (505,455), right half (495,455)).
  - Upper outer leaf: outer R=504, from about 162° to 244°. It is a blade about 20 thick, swelling to about 29 near its lower end,
    with a long taper to the top tip at about (280,4).
  - Upper inner leaf: outer R=478. It thickens from a tip near (214,75) to about 31 where it disappears behind the fall.
  - Lower bands A (R 503→472) and B (R 462→429) pass behind the lower sweep.
  - Two sweeping leaves (C, D) per side rise as points from just under the falls and curve down to the base.
  - Two central stem bars (469–494 and 506–531).
  - Everything is clipped by the outer circle (500,455), R=496.
- Iris flower:
  - Pointed standard petal (tip y=128, widest ≈ x 405–595), with a thin central slit from y≈304 to 440.
  - Two crescent style arms from tips at about (308,306).
  - Two wide side falls, each with a curled upper lobe and notch, a crescent slit from (163,590) to (344,481), and an outer edge
    near x≈30–47.
  - Central bulbs and a heart-shaped lower fall (bottom point y≈806) with an arrow-shaped slit from y≈537 to 676.

## Construction (/tmp/marks/ashina.py)
- Ring leaves and bands: angle-parametrised bands about the measured centres, using the measured width profiles.
- Sweeps: smooth centrelines with width profiles.
- Flower outlines: centripetal Catmull-Rom curves through the measured edge points, with sharp corners only at real tips.
- Overlaps are handled the way the mon itself does it: each piece that passes behind another is cut by that piece buffered by
  9 units, which leaves a white gap.
- The left half is mirrored and everything is unioned in shapely, then scaled by 0.19 into 200x200.

## Simplifications
The small tooth-notch between each side fall and the lower fall is dropped. The slit's diamond widening is smoothed out. The gaps are
standardised to 9 units (about 1.7 viewBox units) so they survive at 300px. Fine detail merges at 30px, where the mark reads as a
round mon with an iris standing in it.

## Verification
research/references/sekiro/ashina-crest-compare.png shows the reference (inverted), a 300px render, a 30px render and the 30px render
enlarged 8x. The SVG was checked with Quick Look.

No rights claimed; personal redraw for a private desktop theme. Sekiro: Shadows Die Twice © FromSoftware / Activision.
