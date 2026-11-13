# Graph Report - veil  (2026-11-13)

## Corpus Check
- 85 files · ~108,989 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 36 file(s) not represented in the graph (top: .toml 14, .otf 5, (none) 4)

## Summary
- 1176 nodes · 2978 edges · 75 communities (45 shown, 30 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 177 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2e0b296e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Palette
- VeilPanelHost
- OSDView
- FocusPulse
- Model
- .fill
- Command
- Int
- Rates
- Item
- Snapshot
- Veil
- .applicationDidFinishLaunching
- metrics.c
- .search
- GlyphRoot
- RecoveryTests
- ClipHistory
- Weather
- veil.sh
- Kind
- CalendarSource
- App
- Darksign — Cinder (dark-souls-3)
- Elden Ring sigil — Guidance (elden-ring)
- Panel
- arasaka-logo: Arasaka Corporation insignia (Cyberpunk 2077)
- Ashina crest — Ashina (sekiro)
- factorio-gear: the gear of the Factorio logo / iron gear wheel item
- hornet-needle (Pharloom / Hollow Knight: Silksong)
- knight-mask (Hallownest / Hollow Knight)
- night-city-emblem: Night City municipal shield monogram (Cyberpunk 2077)
- wings-of-freedom (Paradis / Attack on Titan)
- SIP-gated Now Playing helper
- Paradis: The Wall, seen from inside
- String
- install.sh script
- Action
- dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm
- elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree
- sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk
- DesktopGlyphBoard
- Eclipse — Guts beneath the moon
- integrations.swift
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
- .load
- sync.py
- test_theme.py
- Surface
- .run
- renderReviewFixtureIfRequested
- VeilScreenSaverView
- nothing.notes.md

## God Nodes (most connected - your core abstractions)
1. `Item` - 79 edges
2. `Palette` - 66 edges
3. `Model` - 66 edges
4. `DesktopGlyphBoard` - 55 edges
5. `GlyphRoot` - 48 edges
6. `VeilPanelHost` - 31 edges
7. `DesktopGlyphPin` - 28 edges
8. `selftest()` - 27 edges
9. `DesktopGlyphID` - 25 edges
10. `.p` - 25 edges

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

## Communities (75 total, 30 thin omitted)

### Community 1 - "Palette"
Cohesion: 0.06
Nodes (51): Carbon.HIToolbox, Darwin, ImageIO, acquireInstanceLock(), ActionPanel, .body, canRememberQuery(), code() (+43 more)

### Community 2 - "VeilPanelHost"
Cohesion: 0.05
Nodes (38): Combine, OverviewWindowStrip, .body, .maxThumbs, PassThroughHost, riftWindowsDetailed(), VeilBarController, .barHeight (+30 more)

### Community 3 - "OSDView"
Cohesion: 0.06
Nodes (24): Carbon, IOKit.ps, Brightness, .available, MediaKeys, OSD, OSDKind, battery (+16 more)

### Community 4 - "FocusPulse"
Cohesion: 0.09
Nodes (9): AppKit, ApplicationServices, CoreText, FocusPulse, FocusPulseModel, FocusPulseView, .body, VeilMode (+1 more)

### Community 5 - "Model"
Cohesion: 0.13
Nodes (8): Model, .choosingOverview, .choosingTheme, .currentActions, .gridColumns, .overviewActive, .query, .wsNames

### Community 6 - ".fill"
Cohesion: 0.20
Nodes (9): .lit, RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView (+1 more)

### Community 7 - "Command"
Cohesion: 0.10
Nodes (14): Foundation, VeilThumbs, ScreenCaptureKit, Command, next, pause, play, previous (+6 more)

### Community 8 - "Int"
Cohesion: 0.28
Nodes (4): riftWindows(), score(), SearchTerm, Win

### Community 9 - "Rates"
Cohesion: 0.33
Nodes (3): currencyAnswers(), Rates, .stale

### Community 10 - "Item"
Cohesion: 0.11
Nodes (24): CryptoKit, contactActions(), Item, .canPersist, .id, .isInformational, .key, .learningKey (+16 more)

### Community 11 - "Snapshot"
Cohesion: 0.18
Nodes (10): CoreGraphics, imageURL(), options(), RecoveryError, .description, invalid, restore(), ScreenImage (+2 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - ".applicationDidFinishLaunching"
Cohesion: 0.27
Nodes (4): liveWorkspaceNames(), ncItems(), riftWorkspaceNames(), riftWorkspaces()

### Community 14 - "metrics.c"
Cohesion: 0.17
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - ".search"
Cohesion: 0.13
Nodes (19): CoreServices, add(), defaultTargets(), definitionAnswer(), glyphSurfaceItems(), prefixSearch(), runningAppActions(), shortcutItems() (+11 more)

### Community 16 - "GlyphRoot"
Cohesion: 0.06
Nodes (44): DotField, .body, DotRing, .body, GlyphBtn, GlyphKind, buds, cal (+36 more)

### Community 18 - "ClipHistory"
Cohesion: 0.18
Nodes (5): Clip, ClipHistory, .enabled, utilityAnswers(), withinOneEdit()

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 22 - "Kind"
Cohesion: 0.17
Nodes (10): Kind, action, answer, app, calc, file, nc, setting (+2 more)

### Community 23 - "CalendarSource"
Cohesion: 0.25
Nodes (3): CalendarSource, .events, .reminders

### Community 25 - "Darksign — Cinder (dark-souls-3)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/darksign.py), Darksign — Cinder (dark-souls-3), Geometry read from the icon and the fandom render (they agree), Simplifications, Sources inspected (local copies in research/references/dark-souls-3/), Verification, Why the Darksign

### Community 26 - "Elden Ring sigil — Guidance (elden-ring)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/elden_ring.py), Elden Ring sigil — Guidance (elden-ring), Geometry, measured from the official PNG with a circle Hough transform, residual maps and line probes (reference px), Simplifications, Sources inspected (local copies in research/references/elden-ring/), Verification, Why the logo sigil and not a Site of Grace

### Community 27 - "Panel"
Cohesion: 0.21
Nodes (5): NotchBand, Panel, .canBecomeKey, .canBecomeMain, Scrim

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

### Community 37 - "String"
Cohesion: 0.24
Nodes (8): String, .nilIfEmpty, kindFilter(), obsidianURL(), obsidianVaults(), readVaults(), scriptItems(), SourceCache

### Community 38 - "install.sh script"
Cohesion: 0.33
Nodes (3): install.sh script, build.sh script, build.sh script

### Community 39 - "Action"
Cohesion: 0.50
Nodes (4): Action, copy, open, run

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
Cohesion: 0.06
Nodes (33): DesktopGlyphBoard, .legacyStorePath, .needsMetaTick, .reduceMotion, .storePath, .themeId, DesktopGlyphCanvas, .body (+25 more)

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

### Community 45 - "integrations.swift"
Cohesion: 0.10
Nodes (10): Contacts, EventKit, ContactSource, .status, MenuItems, .trusted, pasteIntoFrontApp(), SafariTabs (+2 more)

### Community 65 - ".load"
Cohesion: 0.31
Nodes (3): SourceSymbol, .aspect, .brand

### Community 69 - "test_theme.py"
Cohesion: 0.13
Nodes (3): luminance(), ratio(), compare()

### Community 70 - "Surface"
Cohesion: 0.40
Nodes (4): Surface, overview, search, themes

### Community 74 - "VeilScreenSaverView"
Cohesion: 0.07
Nodes (8): SymbolContours, QuartzCore, ScreenSaver, Snapshot, Theme, VeilScreenSaverView, DriftView, SaverPreview

## Knowledge Gaps
- **120 isolated node(s):** `.root`, `.animatedPanels`, `.sketchybarPopups`, `.veilBar`, `.overviewLiveThumbs` (+115 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 403 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **30 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `Palette`, `VeilPanelHost`, `OSDView`, `FocusPulse`, `Model`, `.fill`, `Command`, `Int`, `Rates`, `Item`, `Snapshot`, `.applicationDidFinishLaunching`, `.search`, `GlyphRoot`, `ClipHistory`, `Weather`, `Kind`, `CalendarSource`, `Action`, `DesktopGlyphBoard`, `integrations.swift`, `.load`, `.run`, `renderReviewFixtureIfRequested`, `VeilScreenSaverView`?**
  _High betweenness centrality (0.265) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.root`, `.animatedPanels`, `.sketchybarPopups` to the rest of the system?**
  _120 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.11470985155195682 - nodes in this community are weakly interconnected._
- **Why does `Palette` connect `Palette` to `.load`, `VeilPanelHost`, `OSDView`, `FocusPulse`, `String`, `.fill`, `renderReviewFixtureIfRequested`, `DesktopGlyphBoard`, `.applicationDidFinishLaunching`, `GlyphRoot`, `Panel`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Are the 15 inferred relationships involving `Palette` (e.g. with `.revealMenuBar()` and `.sketchybarHidden()`) actually correct?**
  _`Palette` has 15 INFERRED edges - model-reasoned connections that need verification._
- **Should `Palette` be split into smaller, more focused modules?**
  _Cohesion score 0.06404040404040404 - nodes in this community are weakly interconnected._