# Graph Report - veil  (2026-11-13)

## Corpus Check
- 80 files · ~86,835 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 27 file(s) not represented in the graph (top: .toml 13, (none) 4, .patch 1)

## Summary
- 943 nodes · 2213 edges · 64 communities (42 shown, 22 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 147 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c38a0fe4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- veil-theme
- main.swift
- VeilBarController
- OSDView
- FocusPulse
- VeilScreenSaverView
- .fill
- .applicationDidFinishLaunching
- Model
- String
- .search
- Snapshot
- Veil
- Item
- metrics.c
- selftest
- integrations.swift
- RecoveryTests
- ClipHistory
- Weather
- veil.sh
- Kind
- CalendarSource
- .load
- Darksign — Cinder (dark-souls-3)
- Elden Ring sigil — Guidance (elden-ring)
- arasaka-logo: Arasaka Corporation insignia (Cyberpunk 2077)
- Ashina crest — Ashina (sekiro)
- factorio-gear: the gear of the Factorio logo / iron gear wheel item
- hornet-needle (Pharloom / Hollow Knight: Silksong)
- knight-mask (Hallownest / Hollow Knight)
- night-city-emblem: Night City municipal shield monogram (Cyberpunk 2077)
- wings-of-freedom (Paradis / Attack on Titan)
- SIP-gated Now Playing helper
- Paradis: The Wall, seen from inside
- Rates
- install.sh script
- Action
- dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm
- elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree
- sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk
- Surface
- Eclipse — Guts beneath the moon
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

## God Nodes (most connected - your core abstractions)
1. `Item` - 78 edges
2. `Model` - 66 edges
3. `Palette` - 57 edges
4. `selftest()` - 27 edges
5. `.p` - 25 edges
6. `.body` - 24 edges
7. `mono()` - 23 edges
8. `App` - 22 edges
9. `VeilBarController` - 20 edges
10. `Detail` - 20 edges

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

## Communities (64 total, 22 thin omitted)

### Community 0 - "veil-theme"
Cohesion: 0.05
Nodes (5): main(), sync(), luminance(), ratio(), compare()

### Community 1 - "main.swift"
Cohesion: 0.07
Nodes (48): Carbon.HIToolbox, Darwin, ImageIO, acquireInstanceLock(), ActionPanel, .body, code(), Detail (+40 more)

### Community 2 - "VeilBarController"
Cohesion: 0.06
Nodes (34): Combine, OverviewWindowStrip, .body, .maxThumbs, PassThroughHost, riftWindowsDetailed(), VeilBarController, .barLevel (+26 more)

### Community 3 - "OSDView"
Cohesion: 0.06
Nodes (24): Carbon, IOKit.ps, Brightness, .available, MediaKeys, OSD, OSDKind, battery (+16 more)

### Community 4 - "FocusPulse"
Cohesion: 0.05
Nodes (22): AppKit, ApplicationServices, CoreText, Foundation, FocusPulse, FocusPulseModel, FocusPulseView, .body (+14 more)

### Community 5 - "VeilScreenSaverView"
Cohesion: 0.07
Nodes (8): NSView, .firstTextField, QuartzCore, ScreenSaver, Theme, VeilScreenSaverView, DriftView, SaverPreview

### Community 6 - ".fill"
Cohesion: 0.20
Nodes (9): .lit, RNG, SceneArt, SplashView, .body, TitleBlock, .body, WallpaperView (+1 more)

### Community 7 - ".applicationDidFinishLaunching"
Cohesion: 0.11
Nodes (7): App, EscDismiss, NotchBand, Panel, .canBecomeKey, .canBecomeMain, Scrim

### Community 8 - "Model"
Cohesion: 0.10
Nodes (9): kindFilter(), canRememberQuery(), Model, .choosingOverview, .choosingTheme, .gridColumns, .overviewActive, .wsNames (+1 more)

### Community 9 - "String"
Cohesion: 0.14
Nodes (15): String, .nilIfEmpty, isNumericWorkspaceToken(), liveWorkspaceNames(), overviewWorkspaceCards(), riftWindows(), riftWorkspaceNames(), riftWorkspaces() (+7 more)

### Community 10 - ".search"
Cohesion: 0.16
Nodes (17): CryptoKit, definitionAnswer(), .query, aliasItems(), dictURL(), emojiItems(), finderSearchItem(), folderItems() (+9 more)

### Community 11 - "Snapshot"
Cohesion: 0.18
Nodes (10): CoreGraphics, imageURL(), options(), RecoveryError, .description, invalid, restore(), ScreenImage (+2 more)

### Community 12 - "Veil"
Cohesion: 0.10
Nodes (16): Umbra wallpaper, Battery, Credits, Daily use, How theming works, Install, Remove, Rift patch (+8 more)

### Community 13 - "Item"
Cohesion: 0.12
Nodes (17): shortcutItems(), contactActions(), Item, .canPersist, .id, .isInformational, .key, .learningKey (+9 more)

### Community 14 - "metrics.c"
Cohesion: 0.15
Nodes (5): cpu_usage(), delta_is_valid(), die_temp(), main(), sample_cpu()

### Community 15 - "selftest"
Cohesion: 0.19
Nodes (11): CoreServices, add(), defaultTargets(), prefixSearch(), runningAppActions(), systemActionItems(), timeAnswer(), unitAnswers() (+3 more)

### Community 16 - "integrations.swift"
Cohesion: 0.11
Nodes (10): Contacts, EventKit, ContactSource, .status, MenuItems, .trusted, pasteIntoFrontApp(), SafariTabs (+2 more)

### Community 18 - "ClipHistory"
Cohesion: 0.26
Nodes (3): Clip, ClipHistory, .enabled

### Community 19 - "Weather"
Cohesion: 0.22
Nodes (5): SecondaryAction, .id, secondaryActions(), shell(), Weather

### Community 20 - "veil.sh"
Cohesion: 0.30
Nodes (13): cased(), music_bundle_source(), music_draw(), music_feature_off(), music_media_control(), music_panel(), music_read(), music_sip_nowplaying() (+5 more)

### Community 22 - "Kind"
Cohesion: 0.17
Nodes (10): Kind, action, answer, app, calc, file, nc, setting (+2 more)

### Community 23 - "CalendarSource"
Cohesion: 0.25
Nodes (3): CalendarSource, .events, .reminders

### Community 24 - ".load"
Cohesion: 0.21
Nodes (5): SourceSymbol, .aspect, .brand, SymbolContours, Snapshot

### Community 25 - "Darksign — Cinder (dark-souls-3)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/darksign.py), Darksign — Cinder (dark-souls-3), Geometry read from the icon and the fandom render (they agree), Simplifications, Sources inspected (local copies in research/references/dark-souls-3/), Verification, Why the Darksign

### Community 26 - "Elden Ring sigil — Guidance (elden-ring)"
Cohesion: 0.25
Nodes (7): Construction (/tmp/marks/elden_ring.py), Elden Ring sigil — Guidance (elden-ring), Geometry, measured from the official PNG with a circle Hough transform, residual maps and line probes (reference px), Simplifications, Sources inspected (local copies in research/references/elden-ring/), Verification, Why the logo sigil and not a Site of Grace

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

### Community 37 - "Rates"
Cohesion: 0.33
Nodes (3): currencyAnswers(), Rates, .stale

### Community 38 - "install.sh script"
Cohesion: 0.33
Nodes (3): install.sh script, build.sh script, build.sh script

### Community 39 - "Action"
Cohesion: 0.33
Nodes (5): Action, copy, open, run, webSearch()

### Community 40 - "dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm"
Cohesion: 0.40
Nodes (4): dark-souls-3 wallpaper ("Cinder"): Irithyll of the Boreal Valley and Anor Londo under a moonlit storm, Palette (12), Visual weight and top edge, Why this one

### Community 41 - "elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree"
Cohesion: 0.40
Nodes (4): elden-ring wallpaper ("Guidance"): the Shadow Keep on its cliff beneath the Scadutree, Palette (12, `palettegen=max_colors=12`), Visual weight and top edge, Why this one

### Community 42 - "sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk"
Cohesion: 0.40
Nodes (4): Palette (12), sekiro wallpaper ("Ashina"): Fountainhead Palace panorama, waterfall and sakura at dusk, Visual weight and top edge, Why this one

### Community 43 - "Surface"
Cohesion: 0.40
Nodes (4): Surface, overview, search, themes

### Community 44 - "Eclipse — Guts beneath the moon"
Cohesion: 0.50
Nodes (3): Eclipse — Guts beneath the moon, Palette and layout, Status (2026-10-28)

## Knowledge Gaps
- **85 isolated node(s):** `Combine`, `.root`, `.animatedPanels`, `.sketchybarPopups`, `.veilBar` (+80 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 352 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `main.swift`, `VeilBarController`, `OSDView`, `FocusPulse`, `VeilScreenSaverView`, `.fill`, `.applicationDidFinishLaunching`, `Model`, `.search`, `Snapshot`, `Item`, `selftest`, `integrations.swift`, `ClipHistory`, `Weather`, `Kind`, `CalendarSource`, `.load`, `Rates`, `Action`?**
  _High betweenness centrality (0.221) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Item` (e.g. with `.content` and `.hero`) actually correct?**
  _`Item` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Combine`, `.root`, `.animatedPanels` to the rest of the system?**
  _85 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `veil-theme` be split into smaller, more focused modules?**
  _Cohesion score 0.054136874361593465 - nodes in this community are weakly interconnected._
- **Why does `Palette` connect `main.swift` to `VeilBarController`, `OSDView`, `FocusPulse`, `.fill`, `.applicationDidFinishLaunching`, `String`, `Item`, `.load`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **Are the 11 inferred relationships involving `Model` (e.g. with `.applicationDidFinishLaunching()` and `.hide()`) actually correct?**
  _`Model` has 11 INFERRED edges - model-reasoned connections that need verification._
- **Should `main.swift` be split into smaller, more focused modules?**
  _Cohesion score 0.06977808281857699 - nodes in this community are weakly interconnected._