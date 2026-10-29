# Veil

Twelve complete desktop environments for macOS. One command swaps the whole look and feel: tiling, bar, borders,
launcher, terminal, editor, prompt, monitors and wallpaper all change together, each built around a game, anime
or city.

Built on [Rift](https://github.com/acsandmann/rift) (tiling, patched for Hyprland-style animations and directional
resizing), [SketchyBar](https://github.com/FelixKratz/SketchyBar), [JankyBorders](https://github.com/FelixKratz/JankyBorders)
and **Veil Search**, a native ⌘Space launcher that replaces Spotlight.

Themes: Night City, Arasaka, Pharloom, Hallownest, Foundry, The Cabin, New York, Paradis, Eclipse, Guidance, Cinder, Ashina.

## Install

macOS 26+ on Apple Silicon, with Homebrew, Xcode Command Line Tools and Rust (`rustup`) installed.

```sh
git clone https://github.com/DymeYT/veil ~/.config/veil
~/.config/veil/install.sh
```

Then turn off Spotlight's ⌘Space shortcut (System Settings → Keyboard → Keyboard Shortcuts → Spotlight), grant Rift and
Veil Search Accessibility when asked, and run `veil selftest`. `./uninstall.sh` puts your previous settings back.

Optional: `launcher/make-signing-identity.sh` creates a local signing identity so macOS keeps Veil Search's permissions
across rebuilds.

**Wallpapers are not included** (they are copyrighted game and anime art). Put your own image at `art/<theme>.jpg`
(3456×2234 suits a 16" MacBook Pro); `art/<theme>.notes.md` records where each original came from. A good wallpaper
spreads its detail across the frame instead of giving the eye one subject to stare at.

## Daily use

| Do this | How |
| --- | --- |
| Veil Search (Spotlight replacement): apps, files, math, settings, workspaces, commands, themes, web, dictionary | ⌘Space (↵ open, ⌘↵ show in Finder, ⌘C copy, ↑↓/Tab move, Esc close) |
| New terminal window | ⌥Return |
| Resize tiles with the keyboard | ⌥R, then arrows (Shift shrinks a middle tile), Esc to leave |
| Control panel | click the theme chip at the left of the bar |
| Shortcut cheat sheet | click `?` in the bar, or `veil keys` |
| Switch theme | control panel, launcher, or `veil-theme apply arasaka` |
| Undo the last theme change | `veil-theme restore` |
| Battery saver | `veil quiet` (back: `veil normal`) |
| Something looks broken | `veil selftest`, then `veil recover` |

## How theming works

`templates/` holds every themed config, written in the Night City palette (`themes/night-city.toml`).
A theme maps each palette role to a new hex; `veil-theme apply <theme>` swaps the hexes, validates
each file, backs up whatever changes into `backups/`, and writes the new files atomically (rolling all of them back on failure).

- Edit configs in `templates/`, never the live copies, then `veil-theme apply <current theme>`.
- Preview first: `veil-theme diff <theme>`. Check for hand edits: `veil-theme status`.
- New theme: copy a file in `themes/`, change the hexes and the `[strings]` (bar chip, panel title, launcher chip,
  workspace names, fastfetch logo) and `macos_accent`; it appears in the menus automatically.
- Each theme is a full design language: bar information hierarchy, workspace grammar, window spacing,
  terminal frame and font, prompt layout, monitor density, launcher composition, and editor/notes layouts
  all change alongside the palette. See `themes/ECOSYSTEMS.md`; `[style]` in each TOML drives the templates.
- Themes: Night City, Arasaka, Pharloom, Hallownest, Foundry, The Cabin, New York, Paradis (Attack on Titan), Eclipse (Berserk), Guidance, Cinder, and Ashina.
  Applying one also sets the macOS accent color and the theme's wallpaper (`art/<theme>.jpg`).
- After changing the tool: `python3 test_theme.py`.

Themed: Veil Search, Ghostty, SketchyBar, borders, Rift, Starship, fzf, bat, eza (terminal colors), btop, cava, fastfetch, Neovim, Cursor, Obsidian, and the macOS accent color. Twelve distinct launcher compositions include the three-part Arasaka security directory, Guidance's Grace index, Cinder's ember board, and Ashina's selection posture rail. The bar keeps different system readings visible for each theme and moves quieter readings into its control panel.
Not themeable: Safari (follows dark mode and accent), system dialogs, the login screen.

## Veil Search (⌘Space launcher)

Native app in `launcher/` (main.swift, splash.swift, extras.swift, sources.swift). Opens as just the search field; work
happens only while it is open (≈1 ms per keystroke; file results stream in from the Spotlight index). Build: `launcher/build.sh`.

- Search: apps, files (name + content, `pdf:`/`image:`/`folder:`… filters), System Settings, Shortcuts, Cursor projects,
  Chrome/Arc bookmarks, open windows (via Rift), Obsidian vaults, folders by path (`~/Dev/`, Tab enters), typo-tolerant, learns your picks.
- Answers: math (`sqrt(2)`, `15% of 80`), units (`10 km to mi`), currency (`100 usd to eur`, ECB rates on demand), definitions,
  world clock (`time in tokyo`), weather (`weather tokyo`, Open-Meteo after you pause typing), emoji (`:fire`), colours (`#ff8800`),
  `uuid`, `random 1 6`, `password`, `b64 …`, `sha256 …`, clipboard transforms (`upper`, `json`, `count`…).
- Actions: lock, sleep, restart/shut down/log out (system confirms), dark mode, empty Trash (asks), volume, mute, keep awake,
  hidden files, eject, quit/hide/force quit apps (`quit safari`; force quit asks), search prefixes (`g`, `yt`, `gh`, `w`, `maps`, `r`, `amz`),
  quick keys from `launcher/aliases.json`, scripts in `launcher/scripts/` (`# @veil title:` headers), new Obsidian note (`note …`).
- Clipboard history (⌘4 or `clip`): memory only, 8 hours, skips concealed/password-manager copies.
- Keys: ↵ open · ⌘↵/⌘R reveal · ⌘C copy · ⌘Y Quick Look · ⌘K actions · ⌘L Large Type · ⌘P pin · ⌘⌫ Trash ·
  ⌘1–4 apps/files/actions/clipboard · → accept completion · ↑ on empty field recalls searches · Esc clears, then closes.
- With permission: contacts (3+ letters), calendar events and reminders (`event …`, `remind …`), Safari tabs,
  menu-bar search (`m …`), paste into the front app (⌥↵).

## Battery

Measured with `powermetrics --samplers tasks -i 60000` on an idle desktop (MacBook Pro, macOS 27): Rift 1.35 ms/s CPU,
Veil Search 0.84, SketchyBar 0.22, borders 0.02 — together 0.24% of one core, about 2 wake-ups a second, and an energy
impact of 0.56 against 1047 for the whole system. There is no ambient animation; window and workspace animations run
only while something moves.

## Rift patch

`rift/veil.patch` applies to upstream Rift commit `3114cc5` (Apache-2.0). See `rift/README.md`.

## Credits

All franchise and product names in theme titles are descriptive references to works their owners hold; Veil is an
unofficial fan project with no affiliation or endorsement. The vector marks in `art/symbols` are fan-drawn references
(provenance in each `.notes.md`). Code is MIT licensed (`LICENSE`).

## Remove

- `./install.sh` sets up a Mac from scratch (safe to re-run).
- `./uninstall.sh` restores the settings saved at install time from `backups/original`, including theme-owned Cursor keys while keeping unrelated settings.
