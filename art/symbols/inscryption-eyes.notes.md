# inscryption-eyes: Leshy's spiral eyes (Inscryption, Daniel Mullins Games)

## Sources
- Steam library key art (the official capsule): https://cdn.cloudflare.steamstatic.com/steam/apps/1092790/library_600x900_2x.jpg
  Local copy: `research/references/inscryption/steam-library_600x900_2x.jpg`. Leshy's face looms over the cabin, and his irises are glowing orange spirals.
- An in-game screenshot of Leshy's mask with glowing spiral irises ("Please. Consider me pelts!"):
  https://uppercutcrit.com/wp-content/uploads/2022/01/inscryption-Leshy.jpg (`uppercut-leshy-screenshot.jpg`).
- The creator's account of Leshy first appearing as a pair of glowing eyes in the dark: PlayStation Blog, 2022-07-07,
  https://blog.playstation.com/2022/07/07/psychological-horrors-stack-in-devilish-deck-builder-inscryption/ (already cited in research/inscryption.md).
- Checked and rejected:
  - The official Steam logo (`steam-logo.png`) is a plain wordmark with a blood smear. It contains **no eye**, so the "eye on the logo" premise is false.
  - The Steam client icon (`steam-client-icon.png`, 16x16) is a red floppy disk, an OLD_DATA spoiler motif.
  - The card "eye" marking (Reddit: https://i.redd.it/jh12bvclonbb1.png) is an obscure secret, not a recognisable identifier.
  - Leshy's carved boss masks vary from mask to mask and become illegible at 30pt.

## What I inspected
I cropped both eyes from the key art at 4x, and both glowing irises from the screenshot. In the key art each eye is an orange spiral stroke of about 2 turns. It has a round inner head, and its outer arm nearly closes the circle before it opens at the upper outside. The two eyes are mirror images.

## Geometry (viewBox 138 x 64; each eye 60 units across, 14-unit gap)
- An Archimedean centreline from r = 4.8 (head) out to r = 25.7, with 1.55 turns and the tail ending at -28 degrees on the outer side. The left and right eyes are mirrored.
- The stroke is 8.6 units wide, with a round head cap. Over the outer 45% of the arm it tapers to 25% of its width, ending in a round tip.
- Each eye is one simple closed polygon (checked: no self-intersections).

## Simplifications
I cut the spiral from about 2 turns to 1.55 turns, with a wider stroke, so the coils stay open at the launcher size. I omitted the socket hatching and wrinkle lines.
The pair is inherently wide (2.16:1). In the launcher frame (max 30x29) it draws at about 30x14, so each eye is about 13px. At that size it reads as two glowing swirling eyes, but the coil detail is minimal. A wider symbol frame would help.

## Verification
Renders at 300px tall and at the launcher size (30x14): `research/references/inscryption/comparison-inscryption-eyes.png`.

No rights claimed; personal redraw. Inscryption is a trademark of Daniel Mullins Games / Devolver Digital.
