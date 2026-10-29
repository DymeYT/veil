# wings-of-freedom (Paradis / Attack on Titan)

Files: wings-of-freedom.json (launcher), wings-of-freedom.svg (same geometry, one path, evenodd, currentColor).
viewBox 224.69 x 300. 38 contours, each feather a separate filled island. The contours are disjoint, so evenodd and nonzero fill give the same result.

## Sources inspected (local copies in research/references/paradis/)
- https://static.wikia.nocookie.net/shingeki-no-kyogem/images/6/63/Wings_of_Freedom.png (page https://shingeki-no-kyogem.fandom.com/wiki/Survey_Corps). Clean two-colour emblem on the shield.
- https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/i/dfee3ac0-96c7-4f20-bef9-ffeaad744b5f/d6n04bi-2eb6bbc3-57be-49b1-a463-99aeee936e95.png (page https://www.deviantart.com/yumakirosaki/art/Attack-On-Titan-%5BSurvey-Corps-Logo%5D-401433822), 1527x2000. Feather structure was read off a gridded crop of this image.
- https://i.pinimg.com/736x/ef/31/3f/ef313f55a22f02288c173f3fdd33fb4b.jpg (page https://www.pinterest.com/pin/4785143344575338/). Black-and-white line version, used to cross-check feather counts.
- CAVEAT: all three are faithful fan or wiki redraws of the emblem, not a studio or publisher press asset. They agree closely with each other and with the emblem as shown in the anime, but no official vector was obtained.

## True geometry observed
- Two wings, near mirror images about the centre. The front (white) wing's tip is at top right and the back (blue) wing's tip at top left. The front wing overlaps the inner third of the back wing, so the back wing shows only its middle and outer tiers.
- Each wing has three tiers of slanted parallelogram feathers: about 10 inner coverts, 8 secondaries and 7 primaries. The feathers rise toward the outside at about 40 to 50 degrees, get flatter toward the bottom, and have acute rounded tips at upper outside. The outer edge is feathered and serrated. A long leaf-shaped tip feather crowns each wing.
- Quills: each wing ends in a long blade-like stem crossing below. The front stem runs to bottom left and the back stem to bottom right, forming an X.

## Construction
- Four column-boundary splines were traced from the reference (inner edge, two tier channels, outer edge). Rows are spaced by height, and each row line rises 160 to 185 units toward the outside, with a slight downward bow so each feather has a curved belly.
- Each grid cell is a feather. The primaries' tips extend 22% past the outer edge. Each cell is shrunk by half the gap (24 units) and its corners rounded (radius 7).
- The back wing is the mirrored front wing, clipped by the front wing's full outline plus a 1.1x gap. That leaves a hairline channel along the front wing's edge, which is what makes the overlap read in one colour, as the brief asked.
- Shards under the size threshold are removed. The back stem is kept so the crossed quills still show.

## Simplifications
- The shield and its grid are dropped: wings only, which is subtler and avoids the costume-badge look. Feather counts are reduced slightly (9/8/7 + tip). The front wing is a little less diagonal than the original.

## Verification
Rendered via QuickLook at 30, 60 and 300px tall. Comparison: research/references/paradis/wings-of-freedom-comparison.png. At 300px the feathers are crisp and evenly spaced. At 30px @1x the feather gaps blur into texture, but the silhouette still reads: two wings fanning upward, pointed tips, crossed quills. At 60px (30pt Retina) the individual feather rows show.

No rights claimed; personal redraw for a private desktop theme. Attack on Titan is (c) Hajime Isayama / Kodansha.
