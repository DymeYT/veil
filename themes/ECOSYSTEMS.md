# Theme ecosystems

Each theme is a design language, not a palette. `[style]` in a theme file drives shape, type and layout in every
surface; `[strings]` drives text; `[colors]` drives color. Style values may name palette roles as `%role%`.

| | Night City | Arasaka | Pharloom | Hallownest | Foundry | New York | Paradis | Eclipse | Guidance | Cinder | Ashina |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Idea | neon city HUD | red corporate operations center | silk cathedral archive | quiet, pale kingdom | factory control room | MTA wayfinding | field desk | inked black-and-bone study | guidance and field atlas | fading-fire archive | shinobi field kit |
| Bar grammar | two islands | compact red islands | gold hairline | text with no chrome | square instrument plates | full-width signage | bottom desk islands | split, sharp islands | gold-trimmed islands | bare type and diamonds | full-width tactical strip |
| Workspace language | NET/CODE pills | OPS/EXEC/RND/INTEL/VAULT | WEB/FORGE/CHOIR | ◆ ◈ ◇ | RADAR/BUILD/COMMS | WEB/WORK/TALK | WALL/TROST/SCOUT/GATE | ● ◉ ○, active Roman name | GRACE/LIMGRAVE/LIURNIA/ALTUS/ASH | SHRINE/WALLS/CATHEDRAL/IRITHYLL/DREG | ASHINA/HIRATA/CASTLE/DEPTHS/FOUNTAIN |
| Window system | cyan-to-magenta rounded border | close red corporate border | crimson/gold needle | pale, wide breathing gaps | dense orange square grid | taxi-yellow square | cloak-green rounded frame | bone square frame | warm gold rounded frame | ash and ember square frame | slate and rust square frame |
| Terminal | JetBrains Mono, hidden titlebar | compact corporate Mono | Monaspace Xenon | IBM Plex Mono | Monaspace Krypton | Monaspace Neon | Monaspace Radon | IBM Plex Mono | Monaspace Xenon | Victor Mono | Monaspace Argon |
| Shell prompt | two-line city HUD | short command rail | right-side branch/status | centered mark | dense single-line console | route arrow with right-side status | three-part field prompt | cross-like ink mark | guidance glyph | ashen sigil | shinobi bracket |
| Monitor / search | round braille, CPU graph | concise service summary | restrained graphs, tall cards | quiet tree, airy panes | block graphs, process tree, full instrument bar | compact, route-first bar | equipment labels | essential top bar; more data in panel | realm guidance | ember register | posture and selection index |
| Launcher layout | split list/detail | security rail + network directory + action inspector | catalogue + selected archive | full-width airy list | two-column console grid | destination/action route list | field-index rail + results | numbered index + ink rule | grace rail + sites + preview | ember header + two-column register | dojo list + selection gauge + preview |
| Notes / editor | narrow neon notes, minimap | corporate sans notes, dense editor | Cormorant page, needle cursor | Garamond reading page, underline cursor | compact industrial notes, minimap | Helvetica wayfinding | Nunito field journal | Crimson Pro reading page | EB Garamond field notes | Crimson Pro archive | Helvetica field manual |
| Terminal tools | fzf reverse, tall | compact fzf, tight process view | centered fzf, roomy process tree | short fzf, long process names | short fzf, dense process tree | tall fzf, compact list | bottom fzf, roomy | reverse fzf, compact | graceful reverse index | ashen reverse register | default tactical list |

Each column maps to actual settings in `[style]`, and those values feed the shared templates for Rift, SketchyBar, Ghostty, Starship, btop, fastfetch, fzf, Neovim, Obsidian, Cursor and Veil Search. The launcher layouts are different compositions, not just different skins. The bar changes which system readings stay visible and which move into its control panel. These apps expose their own styling APIs; macOS system panels and app content that offer no theme API keep their native layout.

Some app settings have their own lifecycle: Ghostty reloads configuration where supported, while quick-terminal placement and titlebar treatment may need a new window or app restart; btop and Neovim read settings when they start. Theme switching does not force-close those apps.

Arasaka shares some of Night City's terminal foundation, but uses tighter rows, smaller gaps, a three-part security-directory launcher, unique OPS/EXEC/RND/INTEL/VAULT workspaces, corporate wording, a compact monitor and work-first status panel. It is intentionally a corporate workstation variant rather than a color swap.

Wallpaper and splash use `art/<theme>.jpg` for every theme (not shipped; see the README). Each `art/*.notes.md` records the original source, crop and palette.

Third-party game and product names are used as descriptive references for unofficial themes; the project is not affiliated with or endorsed by those rights holders.

There is no ambient wallpaper animation: continuous motion costs battery, and the brief theme-change splash is the only animated surface.

## Environment behavior profiles (2026-10-27)

Display names belong to the environment. Stable historical IDs are implementation details;
commands accept either the display name or its lowercase hyphenated spelling. Existing IDs
continue to work for saved launcher actions and backups.

| Environment | Window default | Editor/navigation | Page composition |
|---|---|---|---|
| Night City | traditional rows/columns | left navigation, sticky context, relative lines | uppercase HUD headings, thin rules |
| Arasaka | primary window + side stack | right navigation, left minimap, boundary whitespace | corporate double rules, heavy quotes |
| Pharloom | traditional rows/columns | single tab, breadcrumb catalogue, quiet gutters | centered serif archive, double rules |
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

## Unapproved border/symbol candidate round

The 2026-10-27 border/symbol round changes native-window outlines to contour-following round
geometry, a 1.25-point active cue and transparent inactive/background strokes for all themes.
The older window-frame descriptions above record prior styling; they do not describe this
candidate's border geometry. Color remains theme-specific. Eclipse also removes the launcher's
redundant inset frame and reduces its launcher/bar strokes to a single point. These changes
are unapproved candidates pending independent Claude visual review, not a new quality baseline.
Read REVIEW-START-HERE.md for the independent two-phase review protocol.

## Panel, fastfetch and statusline forms (2026-10-29)

These three surfaces now change structure per environment, not only colour. The control panel keeps the same actions,
in the same order within each group and with the same shortcuts, so muscle memory carries across themes; what changes
is how it is organised. `python3 tools/compare_themes.py` counts them as the `panel`, `terminal` (fastfetch) and `editor`
(statusline) groups, and `test_theme.py` requires every pair to differ in at least four surface groups.

| Environment | Control panel (`panel_*`) | fastfetch (`ff_layout`) | Neovim statusline (`editor_status_layout`) |
|---|---|---|---|
| Night City | text, status top, keys column, windows first | os host kernel uptime memory battery; swatch block; type mark | hud |
| Arasaka | text, status top, keys column, system first | host os cpu memory processes uptime; swatch none; type mark | directive |
| Pharloom | rule, status top, keys trailing, windows first | os uptime memory; swatch diamond; type mark | thread |
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
