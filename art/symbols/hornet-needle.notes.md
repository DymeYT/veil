# hornet-needle (Pharloom / Hollow Knight: Silksong)

Files: hornet-needle.json (launcher), hornet-needle.svg (same geometry, one path, evenodd, currentColor).
viewBox 244.29 x 300. 3 contours: needle+thread silhouette, the eye hole, and the thread tail (separate because it passes behind the blade).

## Sources inspected (local copies in research/references/pharloom/)
- Team Cherry Silksong promo art of the Needle, via the wiki: https://static.wikia.nocookie.net/hollowknight/images/a/a8/HornetPromo2.jpg (page https://hollowknight.fandom.com/wiki/Needle). Main reference: ring eye, thin handle, asymmetric shoulder (sharp spur on one side, concave cove on the other), silk threads swirling around it.
- In-game Needle icon: https://static0.fextralifeimages.com/file/hollowknightsilksong/a/ad/Needle_hollow_knight_silksong_wiki_guide_128px.png (page https://hollowknightsilksong.wiki.fextralife.com/Needle). Used for proportions: ring about 0.08 of total length, handle about 0.3, blade about 0.6, tapering straight to the point.
- Hornet idle art: https://static.wikia.nocookie.net/hollowknight/images/1/16/Hornet_Idle.png (page https://hollowknight.fandom.com/wiki/Hornet_(Silksong)). Confirms the ring pommel and the long thin blade as she carries it.
- Silksong logo: https://upload.wikimedia.org/wikipedia/fr/a/a2/Hollow_Knight_Silksong_Logo.png and https://static.wikia.nocookie.net/logopedia/images/1/1a/HK-Silksong_logo.png. Checked for a needle-and-thread flourish and found none. The logo's emblem is Hornet's mask over scrollwork, with a small round crest below.

## Why the needle and not the logo
The brief's "logo needle-and-thread flourish" does not exist in the real logo, so drawing one would be invented. The Needle is Hornet's signature weapon. The wiki describes it as "the bladed weapon wielded by Hornet, attached with a thread of Silk", and the needle with its thread is the game's whole premise (silk, song, the Needle). At 30pt a diagonal needle with a looped thread reads clearly and is more elegant than lettering or scrollwork.

## Geometry
- Local axis: eye centred at the origin, point at 1000 units. Eye outer radius 66, hole radius 32. The handle is about 30 wide and widens slightly toward the eye, with a small teardrop neck where it meets the ring.
- Shoulder at about 0.35 to 0.42 of the length, taken from the promo art: an acute spur on one edge and a smooth concave cove on the other. Blade max width about 102 (0.10 of the length), with a faint convex taper to the point.
- Tilted 26 degrees, eye at top right and point at bottom left, close to the promo's diagonal.
- Silk thread: a Bezier centreline turned into a tapered stroke (34 units at the eye down to 9 at the tail). It leaves the top of the eye, lifts up and right, falls in one wide loop and passes behind the blade with an 18-unit knockout gap, then trails off to the left.

## Simplifications
- The needle is drawn bolder than in-game (blade 0.10 of length against about 0.08; handle doubled) so it holds at 30px. The promo's painted bevel is dropped, and its many threads are reduced to one.

## Verification
Rendered via QuickLook (qlmanage) at 30, 60 and 300px tall. Comparison: research/references/pharloom/hornet-needle-comparison.png (reference | 300px | 30px actual | 30px x8). It reads clearly at 60px (30pt Retina). At 30px @1x the thread is a hairline and the blade is about 3px.

No rights claimed; personal redraw for a private desktop theme. Hollow Knight: Silksong is (c) Team Cherry.
