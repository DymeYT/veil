# Theme ecosystems

Each theme is a design language, not a palette. `[style]` in a theme file drives shape, type and layout in every
surface; `[strings]` drives text; `[colors]` drives color. Style values may name palette roles as `%role%`.

| | Night City | Arasaka | Hallownest | Foundry | New York | Paradis | Eclipse | Guidance | Cinder | Ashina |
|---|---|---|---|---|---|---|---|---|---|---|
| Idea | neon city HUD | red corporate operations center | quiet, pale kingdom | factory control room | MTA wayfinding | field desk | inked black-and-bone study | guidance and field atlas | fading-fire archive | shinobi field kit |
| Bar grammar | two islands | compact red islands | text with no chrome | square instrument plates | full-width signage | bottom desk islands | split, sharp islands | gold-trimmed islands | bare type and diamonds | full-width tactical strip |
| Workspace language | NET/CODE pills | OPS/EXEC/RND/INTEL/VAULT | ◆ ◈ ◇ | RADAR/BUILD/COMMS | WEB/WORK/TALK | WALL/TROST/SCOUT/GATE | ● ◉ ○, active Roman name | GRACE/LIMGRAVE/LIURNIA/ALTUS/ASH | SHRINE/WALLS/CATHEDRAL/IRITHYLL/DREG | ASHINA/HIRATA/CASTLE/DEPTHS/FOUNTAIN |
| Window system | cyan contour, moderate gaps | red contour, close gaps | pale contour, wide gaps | orange contour, dense grid | taxi-yellow contour, close gaps | cloak-green contour, moderate gaps | crimson contour, moderate gaps | gold contour, wide gaps | ember contour, wide gaps | rust contour, close gaps |
| Terminal | JetBrains Mono, hidden titlebar | compact corporate Mono | IBM Plex Mono | Monaspace Krypton | Monaspace Neon | Monaspace Radon | IBM Plex Mono | Monaspace Xenon | Victor Mono | Monaspace Argon |
| Shell prompt | two-line city HUD | short command rail | centered mark | dense single-line console | route arrow with right-side status | three-part field prompt | cross-like ink mark | guidance glyph | ashen sigil | shinobi bracket |
| Monitor / search | round braille, CPU graph | concise service summary | quiet tree, airy panes | block graphs, process tree, full instrument bar | compact, route-first bar | equipment labels | essential top bar; more data in panel | realm guidance | ember register | posture and selection index |
| Launcher layout | split list/detail | security rail + network directory + action inspector | full-width airy list | two-column console grid | destination/action route list | field-index rail + results | numbered index + ink rule | grace rail + sites + preview | ember header + two-column register | dojo list + selection gauge + preview |
| Notes / editor | narrow neon notes, minimap | corporate sans notes, dense editor | Garamond reading page, underline cursor | compact industrial notes, minimap | Helvetica wayfinding | Nunito field journal | Crimson Pro reading page | EB Garamond field notes | Crimson Pro archive | Helvetica field manual |
| Terminal tools | fzf reverse, tall | compact fzf, tight process view | short fzf, long process names | short fzf, dense process tree | tall fzf, compact list | bottom fzf, roomy | reverse fzf, compact | graceful reverse index | ashen reverse register | default tactical list |

Each column maps to actual settings in `[style]`, and those values feed the shared templates for Rift, SketchyBar, Ghostty, Starship, btop, fastfetch, fzf, Neovim, Obsidian, Cursor and Veil Search. The launcher layouts are different compositions, not just different skins. The bar changes which system readings stay visible and which move into its control panel. These apps expose their own styling APIs; macOS system panels and app content that offer no theme API keep their native layout.

Some app settings have their own lifecycle: Ghostty reloads configuration where supported, while quick-terminal placement and titlebar treatment may need a new window or app restart; btop and Neovim read settings when they start. Theme switching does not force-close those apps.

Arasaka shares some of Night City's terminal foundation, but uses tighter rows, smaller gaps, a three-part security-directory launcher, unique OPS/EXEC/RND/INTEL/VAULT workspaces, corporate wording, a compact monitor and work-first status panel. It is intentionally a corporate workstation variant rather than a color swap.

Wallpaper and splash use `art/<theme>.jpg`. Umbra includes its credited NASA photograph. Each `art/*.notes.md` records the original source, crop and palette.

Third-party game and product names are used as descriptive references for unofficial themes; the project is not affiliated with or endorsed by those rights holders.

The desktop wallpaper is static. Motion runs during interactions, theme changes, and the active screen saver.


## Umbra

Umbra uses graphite surfaces and pearl type with cyan focus cues. Warm amber
comes from the lunar photograph and marks the theme chip. The bottom bar
centers named workspaces, leaving the top edge and the moon clear. The launcher
uses an eclipse mark, split search and detail, and a solid card. A one-point
focus contour and short window transitions accompany the master-and-stack
layout. Ghostty uses Menlo, native tabs, and a centered quick terminal.
The notes page uses a narrow sans-serif measure and lightly ruled headings,
and the Neovim status line shows mode, diagnostics, encoding, and cursor
location.

[Wallpaper and credit](../art/umbra.notes.md)

## Environment behavior profiles (2026-10-27)

Display names belong to the environment. Stable historical IDs are implementation details;
commands accept either the display name or its lowercase hyphenated spelling. Existing IDs
continue to work for saved launcher actions and backups.

| Environment | Window default | Editor/navigation | Page composition |
|---|---|---|---|
| Night City | traditional rows/columns | left navigation, sticky context, relative lines | uppercase HUD headings, thin rules |
| Arasaka | primary window + side stack | right navigation, left minimap, boundary whitespace | corporate double rules, heavy quotes |
| Hallownest | traditional rows/columns | right navigation, single tab, wrapping, no numbers | centered open reading page, no heading rule |
| Foundry | binary split grid | multiple tabs, sticky context, all whitespace | industrial headings, thick rules |
| New York | horizontal scrolling strip | breadcrumb routes, absolute lines | sans wayfinding, heavy heading rule |
| Paradis | traditional rows/columns | sticky context, wrapping, absolute lines | field journal, uppercase section labels |
| Eclipse | traditional rows/columns | single tab, no line highlight, absolute lines | ink register, double heading rule |
| Guidance | horizontal scrolling strip | right navigation, breadcrumb atlas, wrapping | centered serif field atlas, fine rules |
| Cinder | overlapping visible stack | multiple tabs, wrapping, no sticky context | ashen archive, italic double-rule quotes |
| Ashina | traditional rows/columns | right navigation, sticky context, relative lines | right-aligned manual headings, narrow quotes |

Window modes are real Rift enums verified against the locally installed source. The default
applies to workspaces without a saved/manual layout override; a previously chosen workspace
layout may take precedence. Existing layout hotkeys remain available. No new background
process, recurring animation, polling interval, or third-party dependency was introduced.

Terminal split dimming and titlebar/drop-down placement vary; Cursor also varies sidebar,
tabs, breadcrumbs, sticky context, wrapping, line numbers and whitespace. Neovim varies number,
sign/fold gutters, statusline and column guides. Obsidian gets actual heading/quote/callout
compositions through its existing CSS snippet. These are backed up and reversible. Workspace
settings can override global editor settings; Ghostty frame changes may need a new window.

Run `python3 tools/compare_themes.py` for all 66 comparisons. The automatic gate requires
at least four substantially different non-launcher surface groups per pair, with two
categorical differences to count a group (a real window-mode change counts by itself).
Palette, art, display names, sounds, spacing and launcher IDs cannot satisfy that test.
The independent judgment agent must still evaluate rendered/native-size appearance; passing
configuration comparisons alone does not certify the live desktop.

Implementation references: [VS Code interface settings](https://code.visualstudio.com/docs/editing/getting-started/userinterface),
[Obsidian CSS snippets](https://obsidian.md/help/snippets), and the local Rift protocol enum at
Rift's `crates/rift-protocol/src/layout.rs`.

## Panel, fastfetch and statusline forms (2026-10-29)

These three surfaces now change structure per environment, not only colour. The control panel keeps the same actions,
in the same order within each group and with the same shortcuts, so muscle memory carries across themes; what changes
is how it is organised. `python3 tools/compare_themes.py` counts them as the `panel`, `terminal` (fastfetch) and `editor`
(statusline) groups, and `test_theme.py` requires every pair to differ in at least four surface groups.

| Environment | Control panel (`panel_*`) | fastfetch (`ff_layout`) | Neovim statusline (`editor_status_layout`) |
|---|---|---|---|
| Night City | text, status top, keys column, windows first | os host kernel uptime memory battery; swatch block; type mark | hud |
| Arasaka | text, status top, keys column, system first | host os cpu memory processes uptime; swatch none; type mark | directive |
| Hallownest | space, status top, keys trailing, windows first | uptime memory battery; swatch none; type mark | quiet |
| Foundry | text, status bottom, keys column, system first | cpu gpu memory disk battery uptime; swatch square; picture mark | production |
| New York | text, status top, keys trailing, windows first | os host uptime battery; swatch circle; picture mark | route |
| Paradis | rule, status top, keys trailing, windows first | os kernel uptime memory battery; swatch none; picture mark | field |
| Eclipse | space, status bottom, keys trailing, windows first | kernel uptime; swatch none; type mark | ink |
| Guidance | rule, status top, keys column, system first | os host uptime memory; swatch star; picture mark | atlas |
| Cinder | space, status top, keys column, windows first | os uptime memory battery; swatch triangle; picture mark | ember |
| Ashina | text, status top, keys trailing, system first | os host shell uptime memory; swatch none; picture mark | kanji |

- `panel_headers`: `text` names each group, `rule` adds a hairline after the name, `space` leaves an empty row instead.
- `panel_status`: `bottom` puts the readings line next to a bottom bar. `panel_keys`: `trailing` writes the shortcut after
  the action and drops the column. `panel_first`: which group leads.
- `ff_layout` tokens are `title`, `separator`, `break`, `colors:<symbol>` and `module[:Name]` (see `fastfetch_modules` in
  `bin/veil-theme`). Statusline forms are defined in `templates/nvim.lua`; `hud` keeps LazyVim's own.
- Hallownest and Eclipse hide the statusline (`editor_statusline = 0`); their forms apply when it is turned on.

## Motion and surfaces

Window transitions use short, theme-specific durations. Theme changes use a
single easing curve for the artwork and title reveal, inspired by Hyprland's
event-triggered transitions. Focus uses a one-point window contour, and
Ghostty and the status bar use solid backgrounds for predictable contrast.
Each bar keeps its own placement, type, workspace indicators and selection of
readings, following the range of approaches in JaKooLit's Waybar gallery.
[end-4's usability-first dotfiles](https://github.com/end-4/dots-hyprland)
were a reference for keeping frequently used controls visible and putting
secondary details in the popup.

- [Hyprland animations](https://wiki.hypr.land/0.47.0/Configuring/Animations/)
- [JaKooLit Hyprland-Dots gallery](https://github.com/JaKooLit/Hyprland-Dots/wiki/Gallery)
- [SYNOPTIK on r/unixporn](https://www.reddit.com/r/unixporn/comments/1vvik2t/hyprland_oc_please_enjoy_synoptik_shell_a_fun/), a reference for the on-demand workspace overview

The [Veil screen saver](../screensaver/README.md) reads the active palette and
artwork at launch. It drifts gently while active, and presents a still image
with Reduce Motion enabled.
