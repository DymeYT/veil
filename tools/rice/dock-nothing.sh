#!/bin/bash
# Dock chrome is DISABLED (Big Dawg 2026-11-13). Never mutate Dock size, contents, static-only, or autohide.
# Bar clearance adapts around the Dock; rice must not touch Dock prefs.
set -euo pipefail
cmd="${1:-status}"
case "$cmd" in
  hide|apply|show)
    echo "dock-nothing: no-op (Dock mutation disabled — leave size/apps/autohide alone)" >&2
    exit 0
    ;;
  status|*)
    osascript -e 'tell application "System Events" to tell dock preferences to get {autohide, screen edge, magnification}' 2>/dev/null || true
    printf 'tilesize=%s show-recents=%s static-only=%s\n' \
      "$(defaults read com.apple.dock tilesize 2>/dev/null || echo unset)" \
      "$(defaults read com.apple.dock show-recents 2>/dev/null || echo unset)" \
      "$(defaults read com.apple.dock static-only 2>/dev/null || echo unset)"
    if [ "$cmd" != status ]; then
      echo "usage: dock-nothing.sh [status]  (hide/apply/show are no-ops)" >&2
      exit 1
    fi
    ;;
esac
