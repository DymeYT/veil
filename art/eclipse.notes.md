# Eclipse — Guts beneath the moon

A monochrome manga-style image of Guts seated at the lower right under a full moon, with a broad ink-black sky and fine white snowfall/stars. Visually inspected both the downloaded original and the final crop. No red overlay, Brand of Sacrifice stamp, character collage, added slogan or decorative swords.

- Source page: https://www.wallpaperalchemy.com/wallpaper/guts-berserk-moonlight-manga-wallpaper-4k-418
- Direct downloaded image: https://server.wallpaperalchemy.com/storage/wallpapers/418/guts-berserk-moonlight-manga-wallpaper-4k.jpg
- Berserk creator/art credited by the source tags to **Kentaro Miura**. This is a third-party wallpaper edit; its scan origin, editor, exact manga chapter, and primary rights-holder provenance have not been verified. Do not label the downloaded file an official wallpaper or claim a redistribution license.
- Intended for the user's personal desktop. Retain source credit and do not treat it as a redistributable product asset.
- Original: 3840 × 2160 JPEG. Final: 3456 × 2234 JPEG. Height scales by about 3.4%, then a right-aligned crop removes the left margin and preserves Guts' silhouette and the moon. No AI-generated enlargement or invented linework.
- Final command: ffmpeg -i candidates/eclipse/moonlight.jpg -vf 'scale=3456:2234:force_original_aspect_ratio=increase:flags=lanczos,crop=3456:2234:iw-ow:0' -q:v 2 eclipse.jpg

## Palette and layout

The image is almost pure black and white. Use ink `#070708`, panel `#121214`, quiet frame `#26262a`, secondary warm gray `#9a978f`, bone text `#e8e3d8`. Keep crimson `#c8372f` to tiny selection/cursor/status accents; the wallpaper itself should remain monochrome.

The top edge is mostly black with sparse white specks; a near-opaque black bar gives dependable text contrast. The full moon sits near 20% across / 11% down; Guts occupies the lower-right third. The lower-left area is open and suits a small unglowing serif splash title. Avoid a central title, extra badge, gradient rule or red glow: the ink work carries the theme.

This wallpaper is static. Its snowfall is drawn in the artwork, not animated. No battery-cost claim is made for optional animation.

## Status (2026-10-28)
Restored at the user's request ("the manga artstyle looked really cool"). The film eclipse-sun frame tried in between is kept at candidates/eclipse/eclipse-sun-2026-10-28.*.
