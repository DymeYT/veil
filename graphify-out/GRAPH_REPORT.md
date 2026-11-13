# Graph Report - veil  (2026-11-13)

## Corpus Check
- 86 files · ~113,598 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 37 file(s) not represented in the graph (top: .toml 14, .otf 5, (none) 4)

## Summary
- 1265 nodes · 3273 edges · 82 communities (52 shown, 30 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 187 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8de64837`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Palette
- VeilPanelHost
- SystemControls
- FocusPulse
- Model
- .fill
- NowPlayingSip.swift
- .run
- Item
- String
- Snapshot
- Veil
- VeilBarController
- metrics.c
- VeilPanelView
- GlyphRoot
- RecoveryTests
- ClipHistory
- VeilFeature
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
- bar.swift
- install.sh script
- VeilPanelKind
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
- extras.swift
- sync.py
- test_theme.py
- Surface
- VeilHost
- Weather
- DriftView
- VeilScreenSaverView
- AppKit
- NSView
- Theme
- Command
- Action
- SymbolContours
- nothing.notes.md

## God Nodes (most connected - your core abstractions)
1. `Item` - 79 edges
2. `DesktopGlyphBoard` - 75 edges
3. `Palette` - 68 edges
4. `Model` - 66 edges
5. `GlyphRoot` - 51 edges
6. `DesktopGlyphID` - 41 edges
7. `DesktopGlyphPin` - 39 edges
8. `VeilPanelHost` - 38 edges
9. `DesktopGlyphCanvas` - 29 edges
10. `selftest()` - 27 edges

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

## Communities (82 total, 30 thin omitted)

### Community 1 - "Palette"
Cohesion: 0.06
Nodes (52): Carbon.HIToolbox, Darwin, ImageIO, acquireInstanceLock(), ActionPanel, .body, canRememberQuery(), code() (+44 more)

### Community 2 - "VeilPanelHost"
Cohesion: 0.20
Nodes (3): BatteryDevice, VeilPanelHost, .reduceMotion

### Community 3 - "SystemControls"
Cohesion: 0.05
Nodes (28): Carbon, IOKit.ps, Brightness, .available, MediaKeys, OSD, OSDKind, battery (+20 more)

### Community 4 - "FocusPulse"
Cohesion: 0.10
Nodes (7): ApplicationServices, CoreText, FocusPulse, FocusPulseModel, FocusPulseView, .body, SwiftUI

### Community 5 - "Model"
Cohesion: 0.09
Nodes (12): kindFilter(), Model, .choosingOverview, .choosingTheme, .gridColumns, .overviewActive, .query, .wsNames (+4 more)

### Community 6 - ".fill"
Cohesion: 0.20
Nodes (9): .lit, RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView (+1 more)

### Community 7 - "NowPlayingSip.swift"
Cohesion: 0.22
Nodes (6): loadMediaRemote(), mediaControlPath(), nowPlayingFromMediaControl(), nowPlayingJSON(), runMediaControl(), sipEnabled()

### Community 8 - ".run"
Cohesion: 0.40
Nodes (3): EscDismiss, isNumericWorkspaceToken(), sketchybarWorkspaceNames()

### Community 9 - "Item"
Cohesion: 0.10
Nodes (15): CalendarSource, .events, .reminders, Item, .canPersist, .id, .isInformational, .key (+7 more)

### Community 10 - "String"
Cohesion: 0.12
Nodes (28): CryptoKit, String, .nilIfEmpty, definitionAnswer(), runningAppActions(), calc(), formatNumber(), score() (+20 more)

### Community 11 - "Snapshot"
Cohesion: 0.18
Nodes (10): CoreGraphics, imageURL(), options(), RecoveryError, .description, invalid, restore(), ScreenImage (+2 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - "VeilBarController"
Cohesion: 0.26
Nodes (4): VeilBarController, .barHeight, .barLevel, DateFormatter

### Community 14 - "metrics.c"
Cohesion: 0.17
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - "VeilPanelView"
Cohesion: 0.24
Nodes (7): VeilPanelView, .body, .controlBody, .keysBody, .musicBody, .p, .themeCorner

### Community 16 - "GlyphRoot"
Cohesion: 0.06
Nodes (45): DotField, .body, DotRing, .body, GlyphBtn, GlyphKind, buds, cal (+37 more)

### Community 18 - "ClipHistory"
Cohesion: 0.18
Nodes (3): Clip, ClipHistory, .enabled

### Community 19 - "VeilFeature"
Cohesion: 0.29
Nodes (7): VeilFeature, .animatedPanels, .forceReduceMotion, .overviewLiveThumbs, .root, .sketchybarPopups, .veilBar

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 22 - "Kind"
Cohesion: 0.17
Nodes (10): Kind, action, answer, app, calc, file, nc, setting (+2 more)

### Community 23 - "Kind"
Cohesion: 0.25
Nodes (8): Kind, buds, mac, other, phone, .sortRank, .symbol, watch

### Community 24 - ".applicationDidFinishLaunching"
Cohesion: 0.10
Nodes (13): App, liveWorkspaceNames(), ncItems(), NotchBand, overviewWorkspaceCards(), Panel, .canBecomeKey, .canBecomeMain (+5 more)

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

### Community 37 - "bar.swift"
Cohesion: 0.26
Nodes (7): Combine, OverviewWindowStrip, .body, .maxThumbs, riftWindowsDetailed(), WindowCapture, WinThumb

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
Nodes (40): DesktopGlyphBoard, .legacyStorePath, .needsMetaTick, .reduceMotion, .storePath, .themeId, DesktopGlyphCanvas, .body (+32 more)

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

### Community 45 - "integrations.swift"
Cohesion: 0.11
Nodes (10): Contacts, EventKit, ContactSource, .status, MenuItems, .trusted, pasteIntoFrontApp(), SafariTabs (+2 more)

### Community 65 - "extras.swift"
Cohesion: 0.14
Nodes (12): CoreServices, add(), currencyAnswers(), defaultTargets(), glyphSurfaceItems(), prefixSearch(), Rates, .stale (+4 more)

### Community 69 - "test_theme.py"
Cohesion: 0.13
Nodes (3): luminance(), ratio(), compare()

### Community 70 - "Surface"
Cohesion: 0.40
Nodes (4): Surface, overview, search, themes

### Community 72 - "Weather"
Cohesion: 0.21
Nodes (6): contactActions(), copyText(), SecondaryAction, .id, secondaryActions(), Weather

### Community 73 - "DriftView"
Cohesion: 0.20
Nodes (4): QuartzCore, ScreenSaver, DriftView, SaverPreview

### Community 75 - "AppKit"
Cohesion: 0.22
Nodes (5): AppKit, Foundation, VeilMode, VeilThumbs, ScreenCaptureKit

### Community 76 - "NSView"
Cohesion: 0.22
Nodes (3): PassThroughHost, NSView, .firstTextField

### Community 78 - "Command"
Cohesion: 0.25
Nodes (7): Command, next, pause, play, previous, stop, toggle

### Community 79 - "Action"
Cohesion: 0.40
Nodes (4): Action, copy, open, run

## Knowledge Gaps
- **137 isolated node(s):** `.root`, `.animatedPanels`, `.sketchybarPopups`, `.veilBar`, `.overviewLiveThumbs` (+132 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 425 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **30 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `Palette`, `VeilPanelHost`, `SystemControls`, `FocusPulse`, `Model`, `.fill`, `NowPlayingSip.swift`, `.run`, `Item`, `Snapshot`, `VeilBarController`, `VeilPanelView`, `GlyphRoot`, `ClipHistory`, `VeilFeature`, `Kind`, `Kind`, `.applicationDidFinishLaunching`, `VeilBarView`, `bar.swift`, `VeilPanelKind`, `DesktopGlyphBoard`, `integrations.swift`, `extras.swift`, `VeilHost`, `Weather`, `VeilScreenSaverView`, `Theme`, `Action`, `SymbolContours`?**
  _High betweenness centrality (0.281) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.root`, `.animatedPanels`, `.sketchybarPopups` to the rest of the system?**
  _137 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.11470985155195682 - nodes in this community are weakly interconnected._
- **Why does `Palette` connect `Palette` to `VeilPanelHost`, `SystemControls`, `FocusPulse`, `bar.swift`, `.fill`, `VeilPanelKind`, `.run`, `Item`, `String`, `DesktopGlyphBoard`, `VeilBarController`, `VeilPanelView`, `GlyphRoot`, `.applicationDidFinishLaunching`, `VeilBarView`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `DesktopGlyphBoard` (e.g. with `.body` and `.pinMenu()`) actually correct?**
  _`DesktopGlyphBoard` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Should `Palette` be split into smaller, more focused modules?**
  _Cohesion score 0.06316831683168317 - nodes in this community are weakly interconnected._