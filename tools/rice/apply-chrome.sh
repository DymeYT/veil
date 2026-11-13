#!/bin/bash
# Nothing / Glyph-field desktop chrome: lock dotted wall, tame Dock, clear Finder icons.
# Does not touch launcher/*.swift. Safe to re-run. Restore: tools/rice/restore-chrome.sh
set -euo pipefail

V="${VEIL_ROOT:-$HOME/.config/veil}"
GEN="$V/generated"
ART="$V/art/nothing.jpg"
STATE="$GEN/rice-chrome.json"
QUIET=0
FROM_THEME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1 ;;
    --from-theme) FROM_THEME="${2:-}"; shift ;;
    --from-theme=*) FROM_THEME="${1#*=}" ;;
    -h|--help)
      printf '%s\n' "usage: apply-chrome.sh [--quiet] [--from-theme THEME_ID]"
      exit 0
      ;;
  esac
  shift
done

log() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }

mkdir -p "$GEN"
[ -f "$ART" ] || { echo "missing $ART — run tools/make-nothing-wall.py" >&2; exit 1; }

# Snapshot once so restore can put stock Dock/Finder prefs back.
if [ ! -f "$STATE" ]; then
  python3 - "$STATE" <<'PY'
import json, subprocess, sys
from pathlib import Path

def defaults(domain, key, fallback=None):
    r = subprocess.run(["defaults", "read", domain, key], capture_output=True, text=True)
    if r.returncode != 0:
        return fallback
    return r.stdout.strip()

state = {
    "version": 1,
    "dock": {
        "autohide": defaults("com.apple.dock", "autohide", "0"),
        "tilesize": defaults("com.apple.dock", "tilesize", "48"),
        "magnification": defaults("com.apple.dock", "magnification", "0"),
        "show-recents": defaults("com.apple.dock", "show-recents", "1"),
        "mineffect": defaults("com.apple.dock", "mineffect", "genie"),
        "launchanim": defaults("com.apple.dock", "launchanim", "1"),
        "static-only": defaults("com.apple.dock", "static-only", "0"),
    },
    "finder": {
        "CreateDesktop": defaults("com.apple.finder", "CreateDesktop", "1"),
        "ShowExternalHardDrivesOnDesktop": defaults("com.apple.finder", "ShowExternalHardDrivesOnDesktop", "1"),
        "ShowHardDrivesOnDesktop": defaults("com.apple.finder", "ShowHardDrivesOnDesktop", "0"),
        "ShowRemovableMediaOnDesktop": defaults("com.apple.finder", "ShowRemovableMediaOnDesktop", "1"),
        "ShowMountedServersOnDesktop": defaults("com.apple.finder", "ShowMountedServersOnDesktop", "0"),
    },
}
Path(sys.argv[1]).write_text(json.dumps(state, indent=2) + "\n")
PY
  log "backed up Dock/Finder chrome → $STATE"
fi

# 1) Wallpaper: always re-pin the Glyph field (kills scenic / Style drift on Nothing).
python3 - "$ART" <<'PY' | osascript -l JavaScript >/dev/null 2>&1 || true
import json, sys
art = sys.argv[1]
print(
    "ObjC.import('Foundation'); $.NSDistributedNotificationCenter.defaultCenter"
    ".postNotificationNameObjectUserInfoDeliverImmediately("
    f"'app.veil.search.desktop', {json.dumps(art)}, $(), true)"
)
PY
python3 - "$ART" <<'PY' | osascript >/dev/null 2>&1 || true
import json, sys
print(f'tell application "System Events" to tell every desktop to set picture to {json.dumps(sys.argv[1])}')
PY
printf '%s\n' "$ART" > "$GEN/rice-wall-lock"
log "wallpaper → art/nothing.jpg (Glyph dotted field)"

# 2) Dock: autohide + small + no magnification/recents — bar owns the bottom edge.
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 36
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock static-only -bool true
defaults write com.apple.dock autohide-delay -float 0.05
defaults write com.apple.dock autohide-time-modifier -float 0.35
killall Dock >/dev/null 2>&1 || true
log "Dock → autohide, 36px, no magnify/recents (Nothing-friendly)"

# 3) Finder desktop icons: hide volume/device icons + desktop icon layer for clean Glyph field.
defaults write com.apple.finder CreateDesktop -bool false
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
killall Finder >/dev/null 2>&1 || true
log "Finder → desktop icons hidden (CreateDesktop=false)"

python3 - "$STATE" "$FROM_THEME" "$ART" <<'PY'
import json, sys, time
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text()) if p.exists() else {"version": 1}
data["applied_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
data["from_theme"] = sys.argv[2] or None
data["wallpaper"] = sys.argv[3]
p.write_text(json.dumps(data, indent=2) + "\n")
PY

log "Nothing rice chrome applied. Restore: $V/tools/rice/restore-chrome.sh"
