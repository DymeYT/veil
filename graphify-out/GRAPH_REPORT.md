# Graph Report - veil  (2026-11-13)

## Corpus Check
- 85 files · ~110,867 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 36 file(s) not represented in the graph (top: .toml 14, .otf 5, (none) 4)

## Summary
- 1209 nodes · 3095 edges · 73 communities (46 shown, 27 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 183 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6e83abf2`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Palette
- VeilPanelHost
- OSDView
- FocusPulse
- Item
- .fill
- Command
- main.swift
- Rates
- String
- Snapshot
- Veil
- VeilBarController
- metrics.c
- VeilPanelView
- GlyphRoot
- RecoveryTests
- ClipHistory
- bar.swift
- veil.sh
- Kind
- Kind
- .applicationDidFinishLaunching
- Darksign — Cinder (dark-souls-3)
- Elden Ring sigil — Guidance (elden-ring)
- VeilBarView
- arasaka-logo: Arasaka Corporation insignia (Cyberpunk 2077)
- Ashina crest — Ashina (sekiro)
- factorio-gear: the gear of the Factorio logo / iron gear wheel item
- hornet-needle (Pharloom / Hollow Knight: Silksong)
- knight-mask (Hallownest / Hollow Knight)
- night-city-emblem: Night City municipal shield monogram (Cyberpunk 2077)
- wings-of-freedom (Paradis / Attack on Titan)
- SIP-gated Now Playing helper
- Paradis: The Wall, seen from inside
- OverviewWindowStrip
- install.sh script
- VeilPanelKind
- dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm
- elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree
- sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk
- DesktopGlyphBoard
- Eclipse — Guts beneath the moon
- .activate
- calendar.sh
- subscribe-rift.sh
- run.sh
- arasaka.notes.md
- factorio.notes.md
- hallownest.notes.md
- night-city.notes.md
- nyc.notes.md
- brand-of-sacrifice.notes.md
- umbra-disc.notes.md
- make-signing-identity.sh
- ip.sh
- rift/README.md
- mode-event.sh
- workspace-event.sh
- sip-nowplaying/build.sh
- uninstall.sh
- .search
- sync.py
- test_theme.py
- Surface
- VeilScreenSaverView
- nothing.notes.md

## God Nodes (most connected - your core abstractions)
1. `Item` - 79 edges
2. `DesktopGlyphBoard` - 69 edges
3. `Palette` - 67 edges
4. `Model` - 66 edges
5. `GlyphRoot` - 51 edges
6. `VeilPanelHost` - 37 edges
7. `DesktopGlyphPin` - 37 edges
8. `DesktopGlyphID` - 36 edges
9. `DesktopGlyphCanvas` - 28 edges
10. `selftest()` - 27 edges

## Surprising Connections (you probably didn't know these)
- `Snapshot` --references--> `String`  [EXTRACTED]
  screensaver/Veil.swift → launcher/bar.swift
- `Theme` --references--> `String`  [EXTRACTED]
  screensaver/Veil.swift → launcher/bar.swift
- `VeilScreenSaverView` --references--> `String`  [EXTRACTED]
  screensaver/Veil.swift → launcher/bar.swift
- `nowPlayingJSON()` --references--> `String`  [EXTRACTED]
  tools/sip-nowplaying/NowPlayingSip.swift → launcher/bar.swift
- `imageURL()` --references--> `String`  [EXTRACTED]
  tools/veil-wallpaper.swift → launcher/bar.swift

## Import Cycles
- None detected.

## Communities (73 total, 27 thin omitted)

### Community 1 - "Palette"
Cohesion: 0.07
Nodes (45): ActionPanel, .body, code(), Detail, .actionButton, .body, .content, .fullBody (+37 more)

### Community 2 - "VeilPanelHost"
Cohesion: 0.24
Nodes (3): BatteryDevice, VeilPanelHost, .reduceMotion

### Community 3 - "OSDView"
Cohesion: 0.06
Nodes (24): Carbon, IOKit.ps, Brightness, .available, MediaKeys, OSD, OSDKind, battery (+16 more)

### Community 4 - "FocusPulse"
Cohesion: 0.09
Nodes (9): AppKit, ApplicationServices, CoreText, FocusPulse, FocusPulseModel, FocusPulseView, .body, VeilMode (+1 more)

### Community 5 - "Item"
Cohesion: 0.07
Nodes (22): glyphSurfaceItems(), shortcutItems(), Action, copy, open, run, canRememberQuery(), Item (+14 more)

### Community 6 - ".fill"
Cohesion: 0.20
Nodes (9): .lit, RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView (+1 more)

### Community 7 - "Command"
Cohesion: 0.10
Nodes (13): Foundation, VeilThumbs, ScreenCaptureKit, Command, next, pause, play, previous (+5 more)

### Community 8 - "main.swift"
Cohesion: 0.10
Nodes (17): Carbon.HIToolbox, Darwin, ImageIO, acquireInstanceLock(), EscDismiss, isNumericWorkspaceToken(), riftWorkspaceNames(), scanApps() (+9 more)

### Community 10 - "String"
Cohesion: 0.10
Nodes (30): CryptoKit, String, .nilIfEmpty, definitionAnswer(), contactActions(), score(), SearchTerm, aliasItems() (+22 more)

### Community 11 - "Snapshot"
Cohesion: 0.18
Nodes (10): CoreGraphics, imageURL(), options(), RecoveryError, .description, invalid, restore(), ScreenImage (+2 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - "VeilBarController"
Cohesion: 0.25
Nodes (4): VeilBarController, .barHeight, .barLevel, DateFormatter

### Community 14 - "metrics.c"
Cohesion: 0.17
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - "VeilPanelView"
Cohesion: 0.29
Nodes (7): VeilPanelView, .body, .controlBody, .keysBody, .musicBody, .p, .themeCorner

### Community 16 - "GlyphRoot"
Cohesion: 0.06
Nodes (45): DotField, .body, DotRing, .body, GlyphBtn, GlyphKind, buds, cal (+37 more)

### Community 18 - "ClipHistory"
Cohesion: 0.13
Nodes (5): Clip, ClipHistory, .enabled, utilityAnswers(), Weather

### Community 19 - "bar.swift"
Cohesion: 0.15
Nodes (8): PassThroughHost, VeilFeature, .animatedPanels, .forceReduceMotion, .overviewLiveThumbs, .root, .sketchybarPopups, .veilBar

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 22 - "Kind"
Cohesion: 0.17
Nodes (10): Kind, action, answer, app, calc, file, nc, setting (+2 more)

### Community 23 - "Kind"
Cohesion: 0.17
Nodes (9): Kind, buds, mac, other, phone, .sortRank, .symbol, watch (+1 more)

### Community 24 - ".applicationDidFinishLaunching"
Cohesion: 0.11
Nodes (11): App, liveWorkspaceNames(), ncItems(), NotchBand, overviewWorkspaceCards(), Panel, .canBecomeKey, .canBecomeMain (+3 more)

### Community 25 - "Darksign — Cinder (dark-souls-3)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/darksign.py), Darksign — Cinder (dark-souls-3), Geometry read from the icon and the fandom render (they agree), Simplifications, Sources inspected (local copies in research/references/dark-souls-3/), Verification, Why the Darksign

### Community 26 - "Elden Ring sigil — Guidance (elden-ring)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/elden_ring.py), Elden Ring sigil — Guidance (elden-ring), Geometry, measured from the official PNG with a circle Hough transform, residual maps and line probes (reference px), Simplifications, Sources inspected (local copies in research/references/elden-ring/), Verification, Why the logo sigil and not a Site of Grace

### Community 27 - "VeilBarView"
Cohesion: 0.31
Nodes (5): VeilBarView, .body, .chipButton, .islands, .p

### Community 28 - "arasaka-logo: Arasaka Corporation insignia (Cyberpunk 2077)"
Cohesion: 0.29
Nodes (6): arasaka-logo: Arasaka Corporation insignia (Cyberpunk 2077), Geometry (ring outer radius R = 100 units, centre at (102,102), viewBox 204x204), Simplifications, Sources, Verification, What I inspected

### Community 29 - "Ashina crest — Ashina (sekiro)"
Cohesion: 0.29
Nodes (6): Ashina crest — Ashina (sekiro), Construction (/tmp/marks/ashina.py), Geometry (measured in a 1000x950 frame from row and column black-run probes; mirror-symmetric about x=500), Simplifications, Verification, Verification that the crest exists, and why not 忍

### Community 30 - "factorio-gear: the gear of the Factorio logo / iron gear wheel item"
Cohesion: 0.29
Nodes (6): factorio-gear: the gear of the Factorio logo / iron gear wheel item, Geometry (tooth-tip radius 100, centre (102,102), viewBox 204x204), Simplifications, Sources, Verification, What I inspected

### Community 31 - "hornet-needle (Pharloom / Hollow Knight: Silksong)"
Cohesion: 0.29
Nodes (6): Geometry, hornet-needle (Pharloom / Hollow Knight: Silksong), Simplifications, Sources inspected (local copies in research/references/pharloom/), Verification, Why the needle and not the logo

### Community 32 - "knight-mask (Hallownest / Hollow Knight)"
Cohesion: 0.29
Nodes (6): Geometry (head width = 438 units), knight-mask (Hallownest / Hollow Knight), Simplifications, Sources inspected (local copies in research/references/hallownest/), Verification, Why the mask and not the Pale King / Hallownest crest

### Community 33 - "night-city-emblem: Night City municipal shield monogram (Cyberpunk 2077)"
Cohesion: 0.29
Nodes (6): Geometry (u = 40 units, 2-unit margin, viewBox 244 x 298.08), night-city-emblem: Night City municipal shield monogram (Cyberpunk 2077), Simplifications, Sources, Verification, What I inspected

### Community 34 - "wings-of-freedom (Paradis / Attack on Titan)"
Cohesion: 0.29
Nodes (6): Construction, Simplifications, Sources inspected (local copies in research/references/paradis/), True geometry observed, Verification, wings-of-freedom (Paradis / Attack on Titan)

### Community 35 - "SIP-gated Now Playing helper"
Cohesion: 0.29
Nodes (6): After wake — enable, Commands, Disable / stay usable, Overnight (SIP on) — default, SIP-gated Now Playing helper, Why SIP

### Community 36 - "Paradis: The Wall, seen from inside"
Cohesion: 0.33
Nodes (5): Palette (from palettegen, 12 colors), Paradis: The Wall, seen from inside, Style notes for UI, Visual weight, Why this one

### Community 37 - "OverviewWindowStrip"
Cohesion: 0.29
Nodes (5): OverviewWindowStrip, .body, .maxThumbs, WindowCapture, WinThumb

### Community 38 - "install.sh script"
Cohesion: 0.33
Nodes (3): install.sh script, build.sh script, build.sh script

### Community 39 - "VeilPanelKind"
Cohesion: 0.39
Nodes (4): VeilPanelKind, control, keys, music

### Community 40 - "dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm"
Cohesion: 0.40
Nodes (4): dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm, Palette (12), Visual weight and top edge, Why this one

### Community 41 - "elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree"
Cohesion: 0.40
Nodes (4): elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree, Palette (12, `palettegen=max_colors=12`), Visual weight and top edge, Why this one

### Community 42 - "sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk"
Cohesion: 0.40
Nodes (4): Palette (12), sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk, Visual weight and top edge, Why this one

### Community 43 - "DesktopGlyphBoard"
Cohesion: 0.05
Nodes (40): Combine, DesktopGlyphBoard, .legacyStorePath, .needsMetaTick, .reduceMotion, .storePath, .themeId, DesktopGlyphCanvas (+32 more)

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

### Community 45 - ".activate"
Cohesion: 0.08
Nodes (13): Contacts, EventKit, CalendarSource, .events, .reminders, ContactSource, .status, MenuItems (+5 more)

### Community 65 - ".search"
Cohesion: 0.19
Nodes (14): CoreServices, add(), currencyAnswers(), defaultTargets(), kindFilter(), prefixSearch(), runningAppActions(), systemActionItems() (+6 more)

### Community 69 - "test_theme.py"
Cohesion: 0.13
Nodes (3): luminance(), ratio(), compare()

### Community 70 - "Surface"
Cohesion: 0.40
Nodes (4): Surface, overview, search, themes

### Community 74 - "VeilScreenSaverView"
Cohesion: 0.07
Nodes (9): NSView, .firstTextField, QuartzCore, ScreenSaver, Snapshot, Theme, VeilScreenSaverView, DriftView (+1 more)

## Knowledge Gaps
- **136 isolated node(s):** `.root`, `.animatedPanels`, `.sketchybarPopups`, `.veilBar`, `.overviewLiveThumbs` (+131 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 421 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `Palette`, `VeilPanelHost`, `OSDView`, `FocusPulse`, `Item`, `.fill`, `Command`, `main.swift`, `Rates`, `Snapshot`, `VeilBarController`, `VeilPanelView`, `GlyphRoot`, `ClipHistory`, `bar.swift`, `Kind`, `Kind`, `.applicationDidFinishLaunching`, `VeilBarView`, `OverviewWindowStrip`, `VeilPanelKind`, `DesktopGlyphBoard`, `.activate`, `.search`, `VeilScreenSaverView`?**
  _High betweenness centrality (0.277) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.root`, `.animatedPanels`, `.sketchybarPopups` to the rest of the system?**
  _136 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.11470985155195682 - nodes in this community are weakly interconnected._
- **Why does `Palette` connect `Palette` to `VeilPanelHost`, `OSDView`, `FocusPulse`, `OverviewWindowStrip`, `Item`, `VeilPanelKind`, `main.swift`, `.fill`, `String`, `DesktopGlyphBoard`, `VeilBarController`, `.activate`, `VeilPanelView`, `GlyphRoot`, `.applicationDidFinishLaunching`, `VeilBarView`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `DesktopGlyphBoard` (e.g. with `.body` and `.pinMenu()`) actually correct?**
  _`DesktopGlyphBoard` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Should `Palette` be split into smaller, more focused modules?**
  _Cohesion score 0.0719562243502052 - nodes in this community are weakly interconnected._