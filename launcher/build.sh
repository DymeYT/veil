#!/bin/bash
# Build and install Veil Search (the ⌘Space launcher) to ~/Applications, then (re)start it.
set -euo pipefail
cd "$(dirname "$0")"
app="$HOME/Applications/Veil Search.app"
mkdir -p "$HOME/Applications"
out=$(mktemp -d "$HOME/Applications/.veil-build.XXXXXX")
stage="$out/Veil Search.app"
keep_stage=false
trap '[ "$keep_stage" = true ] || rm -rf "$out"' EXIT
mkdir -p "$stage/Contents/MacOS"
if ! swiftc -O -swift-version 5 -o "$stage/Contents/MacOS/veil-search" main.swift splash.swift extras.swift sources.swift integrations.swift review-render.swift > "$out/build.log" 2>&1; then
  cat "$out/build.log"; echo "build failed; installed Veil Search preserved"; exit 1
fi
cat "$out/build.log"
"$stage/Contents/MacOS/veil-search" --selftest
cat > "$stage/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>app.veil.search</string>
  <key>CFBundleName</key><string>Veil Search</string>
  <key>CFBundleExecutable</key><string>veil-search</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Veil Search controls apps you ask it to, such as switching Safari tabs or playing music.</string>
  <key>NSContactsUsageDescription</key><string>Veil Search shows matching contacts when you search a name.</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Veil Search shows upcoming events and creates events you type.</string>
  <key>NSRemindersFullAccessUsageDescription</key><string>Veil Search creates reminders you type.</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
if [ "${VEIL_BUILD_ONLY:-0}" = 1 ]; then
  keep_stage=true
  echo "built and self-tested (not installed): $stage"
  exit 0
fi
# Preserve a signed installation's designated identity. Never replace it with ad-hoc signing when its key is unavailable.
cert=$(codesign -d -r- "$app" 2>&1 | sed -n 's/.*certificate leaf = H"\([0-9a-f]*\)".*/\1/p' || true)
signer="${cert:--}"
if [ -z "$cert" ]; then
  for n in "Veil Local" "NC Search Local"; do security find-identity -p codesigning 2>/dev/null | grep -q "\"$n\"" && { signer="$n"; break; }; done
fi
codesign --force --sign "$signer" --identifier app.veil.search "$stage" \
  || { echo "signing failed; installed Veil Search preserved"; exit 1; }
codesign --verify --strict "$stage"
backup="$HOME/.config/veil/backups/launcher-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
if [ -d "$app" ]; then mv "$app" "$backup/Veil Search.app"; fi
if ! mv "$stage" "$app"; then
  [ ! -d "$backup/Veil Search.app" ] || mv "$backup/Veil Search.app" "$app"
  echo "install failed; previous Veil Search restored"; exit 1
fi
# Restart through launchd when the login agent runs it. KeepAlive can relaunch a copy
# after a normal quit, so don't start a competing copy with `open` if kickstart fails.
if launchctl print "gui/$(id -u)/app.veil.search" >/dev/null 2>&1; then
  if launchctl kickstart -k "gui/$(id -u)/app.veil.search"; then
    echo "restarted app.veil.search"
  else
    echo "installed successfully; launchd restart was denied. Quit Veil Search in Activity Monitor to let its login agent relaunch it."
  fi
else
  if open "$app"; then
    echo "opened Veil Search"
  else
    echo "installed successfully; open $app to start it"
  fi
fi
echo "installed $app"
