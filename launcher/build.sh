#!/bin/bash
# Build and install Veil Search (the ⌘Space launcher) to ~/Applications, then (re)start it.
set -euo pipefail
cd "$(dirname "$0")"
app="$HOME/Applications/Veil Search.app"
out=$(mktemp -d)
swiftc -O -swift-version 5 -o "$out/veil-search" main.swift splash.swift extras.swift sources.swift integrations.swift review-render.swift 2>&1 | grep -v '^$' || true
[ -x "$out/veil-search" ] || { echo "build failed"; exit 1; }
"$out/veil-search" --selftest
mkdir -p "$app/Contents/MacOS"
cp "$out/veil-search" "$app/Contents/MacOS/veil-search"
cat > "$app/Contents/Info.plist" <<PLIST
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
# a stable identity keeps macOS permissions across rebuilds (make-signing-identity.sh); ad-hoc otherwise
# a stable local identity keeps macOS permissions across rebuilds (make-signing-identity.sh); "NC Search Local" is the pre-rename name
id="-"; for n in "Veil Local" "NC Search Local"; do security find-identity -p codesigning 2>/dev/null | grep -q "\"$n\"" && { id="$n"; break; }; done
codesign --force --sign "$id" "$app" >/dev/null
rm -rf "$out"
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
