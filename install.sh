#!/bin/bash
# Install Veil: dependencies, Rift (with Veil's patch), configs and login services. Safe to re-run.
set -euo pipefail
NC="$HOME/.config/veil"
# fail early, before installing anything, if the build tools are missing
for tool in brew cargo swiftc git; do
  command -v "$tool" >/dev/null || { echo "Veil needs $tool (Homebrew, Rust via rustup, Xcode Command Line Tools, git). Install it and re-run."; exit 1; }
done
RIFT_COMMIT=3114cc5eb3eb6858a3495690312065fe9d95c609  # tested on macOS 27.0.1

brew install sketchybar FelixKratz/formulae/borders fzf zoxide starship bat eza btop fastfetch cava jq
brew install --cask ghostty font-jetbrains-mono-nerd-font font-symbols-only-nerd-font \
  font-cormorant-garamond font-cinzel font-titillium-web font-monaspace font-courier-prime font-special-elite font-rajdhani \
  font-zen-maru-gothic font-victor-mono font-nunito font-maple-mono font-ibm-plex-mono  # theme fonts

mkdir -p "$HOME/.local/bin"
# VEIL_REBUILD_RIFT=1 ./install.sh rebuilds after rift/veil.patch changes (a plain re-run keeps the installed build)
if [ ! -x "$HOME/.local/bin/rift" ] || [ -n "${VEIL_REBUILD_RIFT:-}" ]; then
  # upstream Rift at a tested commit plus rift/veil.patch (Hyprland-style animations, directional resize)
  src="$HOME/Developer/veil-rift"
  [ -d "$src" ] || git clone https://github.com/acsandmann/rift "$src"
  if ! git -C "$src" diff --quiet HEAD; then
    saved="$NC/backups/rift-source/$(date +%Y%m%d-%H%M%S).patch"
    mkdir -p "$(dirname "$saved")"
    git -C "$src" diff --binary HEAD > "$saved"
    echo "Saved previous Rift source changes: $saved"
  fi
  # this clone is Veil's own: reset it so an older copy of the patch never blocks the current one
  git -C "$src" checkout -q -f "$RIFT_COMMIT"
  # Veil's config needs the patched build: stop if the patch does not apply
  git -C "$src" apply "$NC/rift/veil.patch" || { echo "rift/veil.patch did not apply to $src"; exit 1; }
  (cd "$src" && cargo build --release --locked --bin rift --bin rift-cli)
  # Keep the installed designated requirement, so rebuilding does not discard its Accessibility grant.
  # Do this before swapping either executable. A locked/unavailable signing key leaves the running build intact.
  cert=$(codesign -d -r- "$HOME/.local/bin/rift" 2>&1 | sed -n 's/.*certificate leaf = H"\([0-9a-f]*\)".*/\1/p' || true)
  if [ -n "$cert" ]; then
    codesign --force --sign "$cert" --identifier git.acsandmann.rift "$src/target/release/rift" \
      || { echo "Rift built, but its existing signing key is unavailable. Installed Rift was preserved."; exit 1; }
  fi
  # replace by rename: overwriting a running binary in place can get it killed by code signing
  for b in rift rift-cli; do cp "$src/target/release/$b" "$HOME/.local/bin/.$b.new" && mv -f "$HOME/.local/bin/.$b.new" "$HOME/.local/bin/$b"; done
fi
cc -O2 -o "$NC/bin/veil-metrics" "$NC/bin/metrics.c" -framework IOKit -framework CoreFoundation
# record the user's pre-Veil settings and wallpaper before anything changes them, so uninstall.sh can put them back
# (on an existing install the recorder marks missing originals as unavailable instead of saving themed values)
swiftc -O -o "$NC/bin/veil-wallpaper" "$NC/tools/veil-wallpaper.swift"
"$NC/bin/veil-baseline" capture --fresh-install --wallpaper-helper "$NC/bin/veil-wallpaper"
O="$NC/backups/original"
c="$HOME/Library/Application Support/Cursor/User/settings.json"
[ -f "$c" ] && [ ! -f "$O/cursor.settings.json" ] && cp "$c" "$O/cursor.settings.json"
for b in veil veil-theme veil-metrics; do ln -sf "$NC/bin/$b" "$HOME/.local/bin/$b"; done

"$NC/bin/veil-theme" apply "$(cat "$NC/current" 2>/dev/null || echo night-city)"

plist="$HOME/Library/LaunchAgents/git.acsandmann.rift.plist"
[ -f "$plist" ] || "$HOME/.local/bin/rift" service install  # install errors when the service already exists
/usr/libexec/PlistBuddy -c 'Delete :Nice' "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Set :EnvironmentVariables:RUST_LOG warn' "$plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c 'Add :EnvironmentVariables:RUST_LOG string warn' "$plist" 2>/dev/null || true
"$HOME/.local/bin/rift" service restart || "$HOME/.local/bin/rift" service start
# Veil Search: the ⌘Space launcher (native app), started at login and kept running
"$NC/launcher/build.sh"
agent="$HOME/Library/LaunchAgents/app.veil.search.plist"
cat > "$agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>app.veil.search</string>
  <key>ProgramArguments</key><array><string>$HOME/Applications/Veil Search.app/Contents/MacOS/veil-search</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>
PLIST
pkill -x veil-search 2>/dev/null || true
launchctl bootout "gui/$(id -u)/app.veil.search" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$agent" || { sleep 1; launchctl bootstrap "gui/$(id -u)" "$agent"; }  # bootout can lag
brew services restart sketchybar
brew services restart borders

line='[ -f ~/.config/veil/generated/shell.zsh ] && source ~/.config/veil/generated/shell.zsh'
grep -qF "$line" "$HOME/.zshrc" 2>/dev/null || printf '\n# Veil theme colors (fzf, bat)\n%s\n' "$line" >> "$HOME/.zshrc"

cat <<'EOF'
Installed. One-time macOS steps, if not already done:
  - System Settings → Privacy & Security → Accessibility: allow Rift and Veil Search
  - System Settings → Keyboard → Keyboard Shortcuts → Spotlight: turn off ⌘Space (Veil Search uses it)
  - System Settings → Menu Bar: turn on "Show menu bar background" (so the revealed menu bar covers the bar cleanly)
  - First ⌥Return: allow rift to control Ghostty (opens new terminal windows)
Then run: veil selftest
EOF
