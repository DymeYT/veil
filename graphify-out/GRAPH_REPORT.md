# Graph Report - veil-lane-a-vei53  (2026-11-13)

## Corpus Check
- 93 files · ~118,718 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 40 file(s) not represented in the graph (top: .toml 14, (none) 7, .otf 5)

## Summary
- 1374 nodes · 3562 edges · 95 communities (57 shown, 38 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 203 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fc3589b0`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Palette
- VeilPanelHost
- OSDView
- FocusPulse
- NSView
- .fill
- .search
- .applicationDidFinishLaunching
- String
- Snapshot
- Veil
- VeilBarController
- metrics.c
- .controlBody
- .mono
- RecoveryTests
- ClipHistory
- bar.swift
- veil.sh
- Kind
- Kind
- Item
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
- .run
- install.sh script
- Int
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
- .dismiss
- sync.py
- test_theme.py
- NoiseMode
- NowPlayingSip.swift
- CompanionApp
- osd.swift
- VeilScreenSaverView
- Bool
- MediaKeys
- OSD
- GlyphShell
- Weather
- Theme
- GlyphKind
- nothing.notes.md
- AppKit
- DriftView
- GlyphRoot
- App
- Rates
- SIP-gated Now Playing helper
- WsChrome
- StateWatch
- .get
- Action
- saver-companion/build.sh
- ws-chrome/build.sh

## God Nodes (most connected - your core abstractions)
1. `Item` - 79 edges
2. `DesktopGlyphBoard` - 75 edges
3. `Model` - 66 edges
4. `Palette` - 65 edges
5. `VeilPanelHost` - 57 edges
6. `GlyphRoot` - 53 edges
7. `DesktopGlyphID` - 41 edges
8. `DesktopGlyphPin` - 39 edges
9. `SystemControls` - 32 edges
10. `GlyphShell` - 30 edges

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

## Communities (95 total, 38 thin omitted)

### Community 1 - "Palette"
Cohesion: 0.07
Nodes (51): ImageIO, .tileRadius, acquireInstanceLock(), ActionPanel, .body, code(), Detail, .actionButton (+43 more)

### Community 2 - "VeilPanelHost"
Cohesion: 0.13
Nodes (7): VeilPanelHost, .panelWindowFrame, .reduceMotion, VeilPanelKind, control, keys, music

### Community 3 - "OSDView"
Cohesion: 0.21
Nodes (8): OSDModel, OSDView, .accent, .body, .label, .percent, .symbol, .theme

### Community 4 - "FocusPulse"
Cohesion: 0.12
Nodes (4): FocusPulse, FocusPulseModel, FocusPulseView, .body

### Community 5 - "NSView"
Cohesion: 0.17
Nodes (3): NSView, .firstTextField, DriftView

### Community 6 - ".fill"
Cohesion: 0.20
Nodes (9): .lit, RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView (+1 more)

### Community 8 - ".search"
Cohesion: 0.14
Nodes (16): CoreServices, add(), defaultTargets(), definitionAnswer(), glyphSurfaceItems(), prefixSearch(), runningAppActions(), systemActionItems() (+8 more)

### Community 9 - ".applicationDidFinishLaunching"
Cohesion: 0.11
Nodes (19): shortcutItems(), EscDismiss, isNumericWorkspaceToken(), liveWorkspaceNames(), ncItems(), overviewWorkspaceCards(), riftWindows(), riftWorkspaceNames() (+11 more)

### Community 10 - "String"
Cohesion: 0.13
Nodes (25): CryptoKit, riftWindowsDetailed(), String, .nilIfEmpty, WinThumb, aliasItems(), copyText(), emojiItems() (+17 more)

### Community 11 - "Snapshot"
Cohesion: 0.18
Nodes (10): CoreGraphics, imageURL(), options(), RecoveryError, .description, invalid, restore(), ScreenImage (+2 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - "VeilBarController"
Cohesion: 0.21
Nodes (5): VeilBarController, .barHeight, .barLevel, .barWindowFrame, DateFormatter

### Community 14 - "metrics.c"
Cohesion: 0.17
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - ".controlBody"
Cohesion: 0.33
Nodes (7): VeilPanelView, .body, .controlBody, .keysBody, .musicBody, .p, .themeCorner

### Community 16 - ".mono"
Cohesion: 0.17
Nodes (6): .cal, .deck, .home, .prefs, .quick, .vpn

### Community 18 - "ClipHistory"
Cohesion: 0.22
Nodes (3): Clip, ClipHistory, .enabled

### Community 19 - "bar.swift"
Cohesion: 0.12
Nodes (13): Carbon.HIToolbox, Combine, Darwin, PassThroughHost, VeilFeature, .animatedPanels, .forceReduceMotion, .overviewLiveThumbs (+5 more)

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 22 - "Kind"
Cohesion: 0.18
Nodes (10): Kind, action, answer, app, calc, file, nc, setting (+2 more)

### Community 23 - "Kind"
Cohesion: 0.18
Nodes (9): BatteryDevice, Kind, buds, mac, other, phone, .sortRank, .symbol (+1 more)

### Community 24 - "Item"
Cohesion: 0.09
Nodes (18): kindFilter(), contactActions(), canRememberQuery(), Item, .canPersist, .id, .isInformational, .key (+10 more)

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

### Community 37 - ".run"
Cohesion: 0.22
Nodes (6): OverviewWindowStrip, .body, .maxThumbs, .wifiDevice, .wifiOn, WindowCapture

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

### Community 43 - "DesktopGlyphBoard"
Cohesion: 0.05
Nodes (39): DesktopGlyphBoard, .legacyStorePath, .needsMetaTick, .reduceMotion, .storePath, .themeId, DesktopGlyphCanvas, .body (+31 more)

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

### Community 45 - ".activate"
Cohesion: 0.08
Nodes (14): ApplicationServices, Contacts, EventKit, CalendarSource, .events, .reminders, ContactSource, .status (+6 more)

### Community 65 - ".dismiss"
Cohesion: 0.22
Nodes (8): DotRing, .body, GlyphBtn, .charms, .lockMock, .loginMock, .power, .shot

### Community 69 - "test_theme.py"
Cohesion: 0.14
Nodes (3): luminance(), ratio(), compare()

### Community 70 - "NoiseMode"
Cohesion: 0.11
Nodes (13): BudsInfo, .buds, NoiseMode, anc, .hardwareModes, off, openSettings, .title (+5 more)

### Community 71 - "NowPlayingSip.swift"
Cohesion: 0.12
Nodes (13): Command, next, pause, play, previous, stop, toggle, loadMediaRemote() (+5 more)

### Community 72 - "CompanionApp"
Cohesion: 0.17
Nodes (3): IOKit.pwr_mgt, CompanionApp, SaverCompanionMain

### Community 73 - "osd.swift"
Cohesion: 0.17
Nodes (11): Carbon, IOKit.ps, OSDKind, battery, brightness, caps, input, network (+3 more)

### Community 75 - "Bool"
Cohesion: 0.18
Nodes (3): SystemControls, .bluetoothOn, .focusOn

### Community 78 - "GlyphShell"
Cohesion: 0.17
Nodes (5): GlyphShell, .reduceMotion, VPNService, .id, SwiftUI

### Community 81 - "GlyphKind"
Cohesion: 0.13
Nodes (15): GlyphKind, buds, cal, charms, deck, home, lockMock, loginMock (+7 more)

### Community 83 - "AppKit"
Cohesion: 0.14
Nodes (7): AppKit, CoreText, Foundation, VeilMode, VeilThumbs, ScreenCaptureKit, ScreenSaver

### Community 84 - "DriftView"
Cohesion: 0.25
Nodes (3): QuartzCore, DriftView, SaverPreview

### Community 85 - "GlyphRoot"
Cohesion: 0.14
Nodes (13): DotField, .body, GlyphRoot, .bg, .body, .fg, .mediaStrip, .muted (+5 more)

### Community 86 - "App"
Cohesion: 0.08
Nodes (6): App, Panel, .canBecomeKey, .canBecomeMain, Scrim, OutsideClick

### Community 87 - "Rates"
Cohesion: 0.33
Nodes (3): currencyAnswers(), Rates, .stale

### Community 88 - "SIP-gated Now Playing helper"
Cohesion: 0.29
Nodes (6): Commands, Disable, Enable (SIP off), Optional private entitlements, SIP-gated Now Playing helper, Why

### Community 89 - "WsChrome"
Cohesion: 0.33
Nodes (5): WsChrome, .backup, .bordersrc, .flag, .root

### Community 93 - "Action"
Cohesion: 0.50
Nodes (4): Action, copy, open, run

## Knowledge Gaps
- **151 isolated node(s):** `.root`, `.animatedPanels`, `.sketchybarPopups`, `.veilBar`, `.overviewLiveThumbs` (+146 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 458 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **38 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `Palette`, `VeilPanelHost`, `OSDView`, `FocusPulse`, `.fill`, `.refreshControlToggles`, `.search`, `.applicationDidFinishLaunching`, `Snapshot`, `VeilBarController`, `.controlBody`, `.mono`, `ClipHistory`, `bar.swift`, `Kind`, `Kind`, `Item`, `VeilBarView`, `VeilHost`, `.run`, `Int`, `DesktopGlyphBoard`, `.activate`, `.dismiss`, `NoiseMode`, `NowPlayingSip.swift`, `VeilScreenSaverView`, `Bool`, `MediaKeys`, `OSD`, `GlyphShell`, `Weather`, `Theme`, `GlyphKind`, `GlyphRoot`, `App`, `Rates`, `WsChrome`, `Action`?**
  _High betweenness centrality (0.297) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.root`, `.animatedPanels`, `.sketchybarPopups` to the rest of the system?**
  _151 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.10452961672473868 - nodes in this community are weakly interconnected._
- **Why does `DesktopGlyphBoard` connect `DesktopGlyphBoard` to `String`, `OSDView`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `DesktopGlyphBoard` (e.g. with `.body` and `.pinMenu()`) actually correct?**
  _`DesktopGlyphBoard` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Should `Palette` be split into smaller, more focused modules?**
  _Cohesion score 0.06840539922214596 - nodes in this community are weakly interconnected._