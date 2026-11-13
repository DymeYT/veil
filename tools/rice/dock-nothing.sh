#!/bin/bash
# DEPRECATED / REFUSED — preference lock (2026-11-13):
# Never mutate Dock apps, remove Dock apps, shrink tilesize, static-only, or rice Dock chrome.
# Bar clearance around the Dock is OK elsewhere; this script must not write com.apple.dock.
set -euo pipefail

cmd="${1:-status}"

case "$cmd" in
  hide|apply|show|on|off)
    echo "dock-nothing: REFUSED — preference lock: never mutate Dock contents/apps/size." >&2
    echo "Use bar Dock clearance (Lane C) instead. Wallpaper/icons: veil-rice apply (Dock skipped)." >&2
    exit 2
    ;;
  status|*)
    echo "dock-nothing: Dock mutation disabled permanently (preference lock)."
    osascript -e 'tell application "System Events" to tell dock preferences to get {autohide, screen edge, magnification}' 2>/dev/null || true
    printf 'tilesize=%s static-only=%s (read-only; veil-rice will not change these)\n' \
      "$(defaults read com.apple.dock tilesize 2>/dev/null || echo unset)" \
      "$(defaults read com.apple.dock static-only 2>/dev/null || echo unset)"
    if [ "$cmd" != status ]; then
      echo "usage: dock-nothing.sh status  (hide/apply/show permanently refused)" >&2
      exit 1
    fi
    ;;
esac
