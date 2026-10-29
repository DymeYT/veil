# night-city-emblem: Night City municipal shield monogram (Cyberpunk 2077)

## Sources
- Cyberpunk Wiki file `Night_City_Seal_CP2077.png` (878x859), on https://cyberpunk.fandom.com/wiki/Government_of_Night_City:
  https://static.wikia.nocookie.net/cyberpunk/images/2/2f/Night_City_Seal_CP2077.png/revision/latest?cb=20210331041136
  Local copy: `research/references/night-city/fandom-night-city-seal.webp`.
- An in-game screenshot of Night City Hall with the seal cast on the facade, which confirms the in-game use:
  https://static.wikia.nocookie.net/cyberpunk/images/f/f9/Night_City_Hall_01_CP2077.png/revision/latest?cb=20241001141212
  (page https://cyberpunk.fandom.com/wiki/Night_City_Hall). Local copy: `fandom-night-city-hall-ingame.webp`.
- The Night City flag (`fandom-night-city-flag.webp`) was looked at and rejected: it is stripes and stars, with no distinctive mark.

## What I inspected
The full seal reads "NIGHT CITY / THE CITY OF DREAMS / EST. 1994", with laurels and stars. Its distinctive core is a shield whose interior is cut into an "NC" monogram.
I measured the shield's alpha mask by pixel runs. Every cut lies on a grid of unit u = 78.5px, and the shield is exactly 6u wide.

## Geometry (u = 40 units, 2-unit margin, viewBox 244 x 298.08)
Three islands:
1. The top bar (0..6u by 0..1u) with a 45-degree wedge hanging from it. The wedge's vertical edge is on the centre axis, x = 3u, and its tip is at (3u, 2u).
2. A floating rectangle at 4u..6u by 2u..3u, flush with the right edge.
3. The lower body: a left stem at 1u..2u rising from y = 4u up to 2u, and a 45-degree wedge rising from the body to (3u, 3u). The sides run vertically to 4.70u, then at 45 degrees to the apex at (3u, 7.70u).
The shoulder fillets have radius 0.57u and the apex fillet 0.84u (measured 45px and 66px). The top corners are square, as in the source.

## Simplifications
I dropped the ring text, the laurels, the star above the shield, the "EST. 1994" lettering and the star inside the shield. Text and a generic star would be noise at 30pt. The shield monogram is the identifier, and it is clearly distinct from Arasaka's round tree emblem.

## Verification
Renders at 300px and 29px (about 24x29 in the launcher frame): `research/references/night-city/comparison-night-city-emblem.png`.
At 29px the 1u gaps measure about 3.8px, so the monogram stays legible.

No rights claimed; personal redraw. Cyberpunk 2077 is a trademark of CD PROJEKT S.A.
