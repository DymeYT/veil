# Graph Report - veil-vei58  (2026-11-13)

## Corpus Check
- 93 files · ~118,941 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 40 file(s) not represented in the graph (top: .toml 14, (none) 7, .otf 5)

## Summary
- 1385 nodes · 3574 edges · 73 communities (44 shown, 29 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 205 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cf47ac88`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- View
- VeilPanelHost
- OSDView
- FocusPulse
- .load
- .fill
- selftest
- String
- Veil
- Bool
- metrics.c
- .controlBody
- GlyphRoot
- RecoveryTests
- ClipHistory
- VeilFeature
- veil.sh
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
- Paradis: The Wall, seen from inside
- bar.swift
- install.sh script
- main.swift
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
- Item
- sync.py
- test_theme.py
- BudsInfo
- VeilHost
- CompanionApp
- VeilScreenSaverView
- SystemControls
- nothing.notes.md
- .dismiss
- saver-companion/build.sh
- ws-chrome/build.sh

## God Nodes (most connected - your core abstractions)
1. `Item` - 79 edges
2. `DesktopGlyphBoard` - 75 edges
3. `Model` - 66 edges
4. `Palette` - 65 edges
5. `GlyphRoot` - 55 edges
6. `VeilPanelHost` - 50 edges
7. `DesktopGlyphID` - 41 edges
8. `DesktopGlyphPin` - 39 edges
9. `SystemControls` - 30 edges
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

## Communities (73 total, 29 thin omitted)

### Community 1 - "View"
Cohesion: 0.08
Nodes (42): ActionPanel, .body, code(), Detail, .actionButton, .body, .content, .fullBody (+34 more)

### Community 3 - "OSDView"
Cohesion: 0.05
Nodes (30): Carbon, IOKit.ps, Brightness, .available, MediaKeys, OSD, OSDKind, battery (+22 more)

### Community 4 - "FocusPulse"
Cohesion: 0.05
Nodes (23): AppKit, ApplicationServices, Contacts, CoreGraphics, CoreText, EventKit, FocusPulse, FocusPulseModel (+15 more)

### Community 5 - ".load"
Cohesion: 0.26
Nodes (6): SourceSymbol, .aspect, .brand, SymbolContours, VisualEffect, .body

### Community 6 - ".fill"
Cohesion: 0.20
Nodes (9): .lit, RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView (+1 more)

### Community 8 - "selftest"
Cohesion: 0.14
Nodes (13): CoreServices, add(), currencyAnswers(), defaultTargets(), glyphSurfaceItems(), prefixSearch(), Rates, .stale (+5 more)

### Community 10 - "String"
Cohesion: 0.11
Nodes (28): CryptoKit, String, .nilIfEmpty, definitionAnswer(), runningAppActions(), calc(), formatNumber(), aliasItems() (+20 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - "Bool"
Cohesion: 0.22
Nodes (5): VeilBarController, .barHeight, .barLevel, .barWindowFrame, DateFormatter

### Community 14 - "metrics.c"
Cohesion: 0.17
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - ".controlBody"
Cohesion: 0.28
Nodes (7): VeilPanelView, .body, .controlBody, .keysBody, .musicBody, .p, .themeCorner

### Community 16 - "GlyphRoot"
Cohesion: 0.05
Nodes (48): .buds, .emptyBudsState, DotField, .body, DotRing, .body, GlyphBtn, GlyphKind (+40 more)

### Community 18 - "ClipHistory"
Cohesion: 0.18
Nodes (4): Clip, ClipHistory, .enabled, copyText()

### Community 19 - "VeilFeature"
Cohesion: 0.22
Nodes (9): VeilFeature, .animatedPanels, .forceReduceMotion, .overviewLiveThumbs, .root, .saverCompanion, .sketchybarPopups, .veilBar (+1 more)

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 24 - ".applicationDidFinishLaunching"
Cohesion: 0.11
Nodes (10): App, liveWorkspaceNames(), ncItems(), NotchBand, overviewWorkspaceCards(), Panel, .canBecomeKey, .canBecomeMain (+2 more)

### Community 25 - "Darksign — Cinder (dark-souls-3)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/darksign.py), Darksign — Cinder (dark-souls-3), Geometry read from the icon and the fandom render (they agree), Simplifications, Sources inspected (local copies in research/references/dark-souls-3/), Verification, Why the Darksign

### Community 26 - "Elden Ring sigil — Guidance (elden-ring)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/elden_ring.py), Elden Ring sigil — Guidance (elden-ring), Geometry, measured from the official PNG with a circle Hough transform, residual maps and line probes (reference px), Simplifications, Sources inspected (local copies in research/references/elden-ring/), Verification, Why the logo sigil and not a Site of Grace

### Community 27 - "VeilBarView"
Cohesion: 0.35
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
Cohesion: 0.12
Nodes (17): Combine, Darwin, BatteryDevice, Kind, buds, mac, other, phone (+9 more)

### Community 38 - "install.sh script"
Cohesion: 0.33
Nodes (3): install.sh script, build.sh script, build.sh script

### Community 39 - "main.swift"
Cohesion: 0.09
Nodes (21): Carbon.HIToolbox, ImageIO, acquireInstanceLock(), Action, copy, open, run, EscDismiss (+13 more)

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
Nodes (40): DesktopGlyphBoard, .legacyStorePath, .needsMetaTick, .reduceMotion, .storePath, .themeId, DesktopGlyphCanvas, .body (+32 more)

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

### Community 45 - ".activate"
Cohesion: 0.12
Nodes (7): CalendarSource, .events, .reminders, MenuItems, .trusted, pasteIntoFrontApp(), .completion

### Community 65 - "Item"
Cohesion: 0.07
Nodes (23): kindFilter(), contactActions(), SafariTabs, .enabled, canRememberQuery(), Item, .canPersist, .id (+15 more)

### Community 69 - "test_theme.py"
Cohesion: 0.14
Nodes (3): luminance(), ratio(), compare()

### Community 70 - "BudsInfo"
Cohesion: 0.06
Nodes (32): BudsInfo, .showsNoiseControl, .statusLine, FormFactor, earbuds, headset, none, NoiseMode (+24 more)

### Community 71 - "VeilHost"
Cohesion: 0.06
Nodes (22): Foundation, VeilHost, VeilThumbs, ScreenCaptureKit, Command, next, pause, play (+14 more)

### Community 72 - "CompanionApp"
Cohesion: 0.06
Nodes (10): IOKit.pwr_mgt, PassThroughHost, NSView, .firstTextField, QuartzCore, CompanionApp, DriftView, SaverCompanionMain (+2 more)

### Community 74 - "VeilScreenSaverView"
Cohesion: 0.11
Nodes (4): ScreenSaver, Snapshot, Theme, VeilScreenSaverView

### Community 75 - "SystemControls"
Cohesion: 0.10
Nodes (5): SystemControls, .bluetoothOn, .focusOn, .wifiDevice, .wifiOn

### Community 86 - ".dismiss"
Cohesion: 0.15
Nodes (5): VeilPanelKind, control, keys, music, OutsideClick

## Knowledge Gaps
- **159 isolated node(s):** `.animatedPanels`, `.sketchybarPopups`, `.veilBar`, `.overviewLiveThumbs`, `.forceReduceMotion` (+154 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 463 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **29 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `View`, `VeilPanelHost`, `OSDView`, `FocusPulse`, `.load`, `.fill`, `selftest`, `Bool`, `.controlBody`, `GlyphRoot`, `ClipHistory`, `VeilFeature`, `.applicationDidFinishLaunching`, `VeilBarView`, `bar.swift`, `main.swift`, `DesktopGlyphBoard`, `.activate`, `Item`, `BudsInfo`, `VeilHost`, `VeilScreenSaverView`, `SystemControls`, `.dismiss`?**
  _High betweenness centrality (0.312) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.animatedPanels`, `.sketchybarPopups`, `.veilBar` to the rest of the system?**
  _159 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.10452961672473868 - nodes in this community are weakly interconnected._
- **Why does `DesktopGlyphBoard` connect `DesktopGlyphBoard` to `String`, `FocusPulse`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `DesktopGlyphBoard` (e.g. with `.body` and `.pinMenu()`) actually correct?**
  _`DesktopGlyphBoard` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Should `View` be split into smaller, more focused modules?**
  _Cohesion score 0.07839506172839507 - nodes in this community are weakly interconnected._