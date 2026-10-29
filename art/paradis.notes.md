# Paradis: The Wall, seen from inside

Real anime background art, not AI and not fan art: a panoramic matte painting of a walled district (Trost/Shiganshina style) from WIT Studio's *Attack on Titan* (2013 TV anime, Season 1 background art). The stone Wall runs edge to edge with the inner gate at center and a long street leading to it. It has no characters, logos or titans.

- Source page: https://wall.alphacoders.com/big.php?i=1197845 ("A View of Humanity's Last Stand", uploaded by moose512)
- Direct file: https://images6.alphacoders.com/119/1197845.png (5832×2041 PNG)
- Credit: *Attack on Titan* © Hajime Isayama, Kodansha / "Attack on Titan" Production Committee; anime background art by WIT Studio. The upload does not record whether it is an art-book scan or a stitched pan from the show, so that is not verified. Use it only as a personal desktop wallpaper.
- Output: 3456×2234 JPEG. Command:
  `ffmpeg -i candidates/paradis/1197845.png -vf "crop=3157:2041:1163:0,scale=3456:2234:flags=lanczos,eq=saturation=0.72:gamma=0.9:brightness=-0.03,format=rgb24,geq=…bottom 14% fade to 50%…" -q:v 2 paradis.jpg`
  The crop is a 16:10 window centered on the gate, upscaled 1.095×. A mild grade mutes the painting toward overcast stone and leather (saturation 0.72, slightly darker). The bottom 14% fades to 50% brightness to calm the bottom bar edge. No pixels were invented. For the untouched look, rerun with only `crop,scale`.

## Why this one
The Wall is the single motif that means "Paradis", and it reads here as architecture and atmosphere, not spectacle. It is official production art at native ~3K height. Alternatives reviewed on disk:
- `1410659.jpg`: the official MAPPA *Final Chapters* key visual (Mikasa and the tree on the hill). It is beautiful, but the golden, sentimental tone would not survive a 16:10 crop.
- `1379590.png`: an edited frame from the anime with a centered child silhouette in bright blue clouds. It feels too poster-like.
- `925166.jpg`: a moody sunrise over the wall, but it is fan art (Pablo Dominguez) and only 2700×1080, so it is excluded under the real-art rule.

## Palette (from palettegen, 12 colors)
| Role | Hex |
|---|---|
| Darkest bg (bar fill) | `#171308` (fade floor `#030301`) |
| Surface 1 | `#2a2519` |
| Surface 2 / panels | `#413c2f` |
| Borders, inactive | `#575142` |
| Muted text, stone | `#736c5a` |
| Secondary accent (brass / roof tan) | `#968a6e` |
| Primary accent (overcast blue) | `#8197aa` |
| Bright accent (sky, use sparingly) | `#7da6d3` |
| Soft highlight | `#99acba` |
| Highlight | `#bacedb` |
| Text (cool parchment) | `#d3e3e8` |

Survey Corps cloak green is not in the art. If wanted, use a desaturated `#5f6b45` for tiny marks only.

## Visual weight
- Top ~25%: open, soft blue-grey cloud. Calm and empty.
- 25–37%: the horizontal band of the Wall, which is the main read. The gate sits at about 50% across and 30% down.
- The lower 60% is dense rooftops, warmest and busiest at bottom-left and bottom-right. The bottom bar sits on the faded strip and should be a near-opaque `#171308`, never translucent cream.
- A title or splash fits in the sky at upper left. Keep the center column (the street and gate) clear.

## Style notes for UI
1. Painterly but realistic matte painting: soft-edged clouds, crisp hard-edged masonry, no outlines. Use flat fills and thin 1px hairlines. Avoid glows and heavy shadows.
2. The palette is earth and stone (umber roofs, grey ashlar) against one cool sky. Keep UI mostly warm-neutral with one cool accent.
3. The light is flat and overcast, so gradients should be very shallow. Avoid specular highlights.
4. The show's logo is a heavy, condensed, slab-like Latin wordmark with chiselled, angular cuts (the JP 進撃の巨人 logo is blocky and stencil-like). For UI, use a condensed grotesk or slab in caps with wide tracking. Avoid a fantasy blackletter.
5. Geometry repeats in the Wall's buttresses, which give a regular vertical rhythm. That rhythm suits a strict grid and evenly spaced bar segments.
