#!/bin/bash
# Nothing / Glyph-field desktop chrome: lock dotted wall + optional Finder icon hide.
# HARD RULE (preferences): NEVER mutate Dock apps, tilesize, static-only, or any Dock contents.
# Does not touch launcher/*.swift. Restore Finder-only: tools/rice/restore-chrome.sh
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
      printf '%s\n' "Applies Glyph wallpaper + Finder desktop-icon hide. Never touches Dock."
      exit 0
      ;;
  esac
  shift
done

log() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }

mkdir -p "$GEN"
[ -f "$ART" ] || { echo "missing $ART — run tools/make-nothing-wall.py" >&2; exit 1; }

# Snapshot Finder prefs once (Dock intentionally omitted — preference lock).
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
    "version": 2,
    "dock": "skipped",  # preference lock — never backup/mutate Dock
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
  log "backed up Finder chrome → $STATE (Dock skipped permanently)"
fi

# 1) Wallpaper: re-pin the Glyph field (kills scenic / Style drift on Nothing).
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

# 2) Dock: SKIPPED permanently (preference lock — never apps/size/static-only/autohide writes).
log "Dock → skipped (preference: never mutate Dock contents)"

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
data = json.loads(p.read_text()) if p.exists() else {"version": 2}
data["version"] = 2
data["dock"] = "skipped"
data["applied_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
data["from_theme"] = sys.argv[2] or None
data["wallpaper"] = sys.argv[3]
p.write_text(json.dumps(data, indent=2) + "\n")
PY

log "Nothing rice chrome applied (wall + Finder only). Restore: $V/tools/rice/restore-chrome.sh"
