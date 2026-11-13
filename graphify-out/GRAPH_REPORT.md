# Graph Report - veil-ux-loop  (2026-11-13)

## Corpus Check
- 99 files · ~123,441 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 40 file(s) not represented in the graph (top: .toml 14, (none) 7, .otf 5)

## Summary
- 1443 nodes · 3717 edges · 101 communities (58 shown, 43 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 214 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a6730841`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Palette
- VeilPanelHost
- .show
- FocusPulse
- .font
- .fill
- DesktopGlyphBoard
- Item
- Model
- .search
- AppKit
- Veil
- VeilBarController
- metrics.c
- .controlBody
- GlyphRoot
- RecoveryTests
- ClipHistory
- VeilFeature
- veil.sh
- DesktopGlyphCanvas
- .run
- .metrics
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
- VeilHost
- Paradis: The Wall, seen from inside
- bar.swift
- install.sh script
- .show
- dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm
- elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree
- sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk
- DesktopGlyphPin
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
- GlyphBoardHost
- re
- test_theme.py
- BudsInfo
- NowPlayingSip.swift
- main.swift
- make-nothing-wall.py
- CompanionApp
- Bool
- Nothing rice chrome (Lane E / VEI-57)
- DesktopGlyphID
- Weather
- .applicationDidFinishLaunching
- apply-chrome.sh
- nothing.notes.md
- String
- SourceSymbol
- restore-chrome.sh
- App
- Rates
- desktop-icons.sh
- dock-nothing.sh
- CalendarSource
- Kind
- Action
- saver-companion/build.sh
- ws-chrome/build.sh
- .num
- .icon
- .run
- .show
- renderReviewFixtureIfRequested

## God Nodes (most connected - your core abstractions)
1. `DesktopGlyphBoard` - 87 edges
2. `Item` - 79 edges
3. `Model` - 66 edges
4. `Palette` - 65 edges
5. `VeilPanelHost` - 58 edges
6. `GlyphRoot` - 55 edges
7. `DesktopGlyphID` - 41 edges
8. `DesktopGlyphPin` - 39 edges
9. `SystemControls` - 32 edges
10. `BudsInfo` - 30 edges

## Surprising Connections (you probably didn't know these)
- `Snapshot` --references--> `String`  [EXTRACTED]
  screensaver/Veil.swift → launcher/bar.swift
- `Theme` --references--> `String`  [EXTRACTED]
  screensaver/Veil.swift → launcher/bar.swift
- `VeilScreenSaverView` --references--> `String`  [EXTRACTED]
  screensaver/Veil.swift → launcher/bar.swift
- `mediaControlPath()` --references--> `String`  [EXTRACTED]
  tools/sip-nowplaying/NowPlayingSip.swift → launcher/bar.swift
- `nowPlayingFromMediaControl()` --references--> `String`  [EXTRACTED]
  tools/sip-nowplaying/NowPlayingSip.swift → launcher/bar.swift

## Import Cycles
- None detected.

## Communities (101 total, 43 thin omitted)

### Community 1 - "Palette"
Cohesion: 0.19
Nodes (14): ActionPanel, .kindLabel, Frame, GroupHeader, LauncherView, .body, .layout, .gridColumns (+6 more)

### Community 2 - "VeilPanelHost"
Cohesion: 0.16
Nodes (7): VeilPanelHost, .panelWindowFrame, .reduceMotion, VeilPanelKind, control, keys, music

### Community 3 - ".show"
Cohesion: 0.05
Nodes (31): Carbon, IOKit.ps, Brightness, .available, MediaKeys, OSD, OSDKind, battery (+23 more)

### Community 4 - "FocusPulse"
Cohesion: 0.12
Nodes (4): FocusPulse, FocusPulseModel, FocusPulseView, .body

### Community 5 - ".font"
Cohesion: 0.22
Nodes (16): .body, code(), Detail, .actionButton, .body, .content, .fullBody, .hero (+8 more)

### Community 6 - ".fill"
Cohesion: 0.21
Nodes (8): RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView, .body

### Community 7 - "DesktopGlyphBoard"
Cohesion: 0.11
Nodes (6): DesktopGlyphBoard, .legacyStorePath, .needsMetaTick, .reduceMotion, .storePath, .themeId

### Community 8 - "Item"
Cohesion: 0.13
Nodes (21): CoreServices, add(), defaultTargets(), glyphSurfaceItems(), prefixSearch(), runningAppActions(), shortcutItems(), systemActionItems() (+13 more)

### Community 9 - "Model"
Cohesion: 0.12
Nodes (9): canRememberQuery(), Model, .choosingOverview, .choosingTheme, .overviewActive, riftWorkspaceNames(), themeTomlWorkspaceNames(), Win (+1 more)

### Community 10 - ".search"
Cohesion: 0.14
Nodes (20): CryptoKit, definitionAnswer(), .query, aliasItems(), bookmarkItems(), cursorProjects(), dictURL(), emojiItems() (+12 more)

### Community 11 - "AppKit"
Cohesion: 0.06
Nodes (23): AppKit, CoreGraphics, CoreText, Foundation, VeilMode, VeilThumbs, ScreenCaptureKit, DriftView (+15 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - "VeilBarController"
Cohesion: 0.13
Nodes (7): PassThroughHost, VeilBarController, .barHeight, .barLevel, .barWindowFrame, NSView, .firstTextField

### Community 14 - "metrics.c"
Cohesion: 0.17
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - ".controlBody"
Cohesion: 0.33
Nodes (7): VeilPanelView, .body, .controlBody, .keysBody, .musicBody, .p, .themeCorner

### Community 16 - "GlyphRoot"
Cohesion: 0.05
Nodes (48): .buds, .emptyBudsState, DotField, .body, DotRing, .body, GlyphBtn, GlyphKind (+40 more)

### Community 18 - "ClipHistory"
Cohesion: 0.17
Nodes (4): Clip, ClipHistory, .enabled, copyText()

### Community 19 - "VeilFeature"
Cohesion: 0.22
Nodes (9): VeilFeature, .animatedPanels, .forceReduceMotion, .overviewLiveThumbs, .root, .saverCompanion, .sketchybarPopups, .veilBar (+1 more)

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 22 - "DesktopGlyphCanvas"
Cohesion: 0.26
Nodes (10): DesktopGlyphCanvas, .body, .cavaWidget, .clockWidget, .mediaWidget, .p, .quickWidget, .reduceMotion (+2 more)

### Community 23 - ".run"
Cohesion: 0.12
Nodes (11): BatteryDevice, Kind, buds, mac, other, phone, .sortRank, .symbol (+3 more)

### Community 25 - "Darksign — Cinder (dark-souls-3)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/darksign.py), Darksign — Cinder (dark-souls-3), Geometry read from the icon and the fandom render (they agree), Simplifications, Sources inspected (local copies in research/references/dark-souls-3/), Verification, Why the Darksign

### Community 26 - "Elden Ring sigil — Guidance (elden-ring)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/elden_ring.py), Elden Ring sigil — Guidance (elden-ring), Geometry, measured from the official PNG with a circle Hough transform, residual maps and line probes (reference px), Simplifications, Sources inspected (local copies in research/references/elden-ring/), Verification, Why the logo sigil and not a Site of Grace

### Community 27 - "VeilBarView"
Cohesion: 0.42
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

### Community 36 - "Paradis: The Wall, seen from inside"
Cohesion: 0.33
Nodes (5): Palette (from palettegen, 12 colors), Paradis: The Wall, seen from inside, Style notes for UI, Visual weight, Why this one

### Community 37 - "bar.swift"
Cohesion: 0.21
Nodes (7): Carbon.HIToolbox, OverviewWindowStrip, .body, .maxThumbs, riftWindowsDetailed(), WindowCapture, WinThumb

### Community 38 - "install.sh script"
Cohesion: 0.33
Nodes (3): install.sh script, build.sh script, build.sh script

### Community 40 - "dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm"
Cohesion: 0.40
Nodes (4): dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm, Palette (12), Visual weight and top edge, Why this one

### Community 41 - "elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree"
Cohesion: 0.40
Nodes (4): elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree, Palette (12, `palettegen=max_colors=12`), Visual weight and top edge, Why this one

### Community 42 - "sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk"
Cohesion: 0.40
Nodes (4): Palette (12), sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk, Visual weight and top edge, Why this one

### Community 43 - "DesktopGlyphPin"
Cohesion: 0.19
Nodes (4): DesktopGlyphPin, .spanCols, .spanRows, Store

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

### Community 45 - "integrations.swift"
Cohesion: 0.09
Nodes (11): ApplicationServices, Contacts, EventKit, ContactSource, .status, MenuItems, .trusted, pasteIntoFrontApp() (+3 more)

### Community 69 - "test_theme.py"
Cohesion: 0.17
Nodes (3): luminance(), ratio(), compare()

### Community 70 - "BudsInfo"
Cohesion: 0.08
Nodes (22): BudsInfo, .showsNoiseControl, .statusLine, FormFactor, earbuds, headset, none, NoiseMode (+14 more)

### Community 71 - "NowPlayingSip.swift"
Cohesion: 0.12
Nodes (13): Command, next, pause, play, previous, stop, toggle, loadMediaRemote() (+5 more)

### Community 72 - "main.swift"
Cohesion: 0.11
Nodes (13): ImageIO, acquireInstanceLock(), hexColor(), isNumericWorkspaceToken(), Pressable, sketchybarWorkspaceNames(), ThemeFonts, .body (+5 more)

### Community 74 - "CompanionApp"
Cohesion: 0.05
Nodes (10): IOKit.pwr_mgt, SymbolContours, QuartzCore, ScreenSaver, Snapshot, Theme, VeilScreenSaverView, CompanionApp (+2 more)

### Community 75 - "Bool"
Cohesion: 0.15
Nodes (3): SystemControls, .bluetoothOn, .focusOn

### Community 76 - "Nothing rice chrome (Lane E / VEI-57)"
Cohesion: 0.40
Nodes (4): Commands, Finder icons, Nothing rice chrome (Lane E / VEI-57), Scenic-wall conflict

### Community 78 - "DesktopGlyphID"
Cohesion: 0.09
Nodes (19): Combine, Darwin, DesktopGlyphID, battery, cava, clock, cpu, .defaultSpan (+11 more)

### Community 79 - "Weather"
Cohesion: 0.21
Nodes (5): SecondaryAction, .id, secondaryActions(), shell(), Weather

### Community 80 - ".applicationDidFinishLaunching"
Cohesion: 0.21
Nodes (6): liveWorkspaceNames(), ncItems(), riftWindows(), riftWorkspaces(), scanApps(), .body

### Community 83 - "String"
Cohesion: 0.20
Nodes (9): String, .nilIfEmpty, kindFilter(), calc(), formatNumber(), score(), SearchTerm, windowItems() (+1 more)

### Community 84 - "SourceSymbol"
Cohesion: 0.21
Nodes (6): .body, PanelShape, SourceSymbol, .aspect, .brand, .body

### Community 86 - "App"
Cohesion: 0.15
Nodes (5): App, NotchBand, Panel, .canBecomeKey, .canBecomeMain

### Community 87 - "Rates"
Cohesion: 0.33
Nodes (3): currencyAnswers(), Rates, .stale

### Community 90 - "CalendarSource"
Cohesion: 0.25
Nodes (3): CalendarSource, .events, .reminders

### Community 91 - "Kind"
Cohesion: 0.18
Nodes (10): Kind, action, answer, app, calc, file, nc, setting (+2 more)

### Community 93 - "Action"
Cohesion: 0.33
Nodes (5): Action, copy, open, run, webSearch()

### Community 96 - ".num"
Cohesion: 0.25
Nodes (6): .tileRadius, .panelRadius, Row, .lit, .selection, .style

## Knowledge Gaps
- **159 isolated node(s):** `.animatedPanels`, `.sketchybarPopups`, `.veilBar`, `.overviewLiveThumbs`, `.forceReduceMotion` (+154 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 479 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **43 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `Palette`, `VeilPanelHost`, `.show`, `FocusPulse`, `.font`, `.fill`, `DesktopGlyphBoard`, `Item`, `Model`, `.search`, `AppKit`, `VeilBarController`, `.controlBody`, `GlyphRoot`, `ClipHistory`, `VeilFeature`, `DesktopGlyphCanvas`, `.run`, `VeilBarView`, `VeilHost`, `bar.swift`, `.show`, `DesktopGlyphPin`, `integrations.swift`, `BudsInfo`, `NowPlayingSip.swift`, `main.swift`, `CompanionApp`, `Bool`, `DesktopGlyphID`, `Weather`, `.applicationDidFinishLaunching`, `SourceSymbol`, `Rates`, `CalendarSource`, `Kind`, `Action`, `.num`, `.icon`, `.run`, `renderReviewFixtureIfRequested`?**
  _High betweenness centrality (0.291) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `DesktopGlyphBoard` (e.g. with `.body` and `.pinMenu()`) actually correct?**
  _`DesktopGlyphBoard` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.animatedPanels`, `.sketchybarPopups`, `.veilBar` to the rest of the system?**
  _159 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.12091038406827881 - nodes in this community are weakly interconnected._
- **Why does `DesktopGlyphBoard` connect `DesktopGlyphBoard` to `GlyphBoardHost`, `FocusPulse`, `DesktopGlyphPin`, `DesktopGlyphID`, `String`, `DesktopGlyphCanvas`, `.metrics`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Should `.show` be split into smaller, more focused modules?**
  _Cohesion score 0.050203527815468114 - nodes in this community are weakly interconnected._