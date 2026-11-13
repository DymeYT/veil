#!/bin/bash
# Nothing-friendly Dock (autohide) without touching Finder/wallpaper.
# hide   — apply rice Dock settings
# show   — force Dock always visible (keeps size)
# status — print Dock prefs
set -euo pipefail

cmd="${1:-status}"

case "$cmd" in
  hide|apply)
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
    echo "Dock: autohide + 36px + no recents (Nothing)."
    ;;
  show)
    defaults write com.apple.dock autohide -bool false
    killall Dock >/dev/null 2>&1 || true
    echo "Dock: always visible."
    ;;
  status|*)
    osascript -e 'tell application "System Events" to tell dock preferences to get {autohide, screen edge, magnification}' 2>/dev/null || true
    printf 'tilesize=%s show-recents=%s static-only=%s\n' \
      "$(defaults read com.apple.dock tilesize 2>/dev/null || echo unset)" \
      "$(defaults read com.apple.dock show-recents 2>/dev/null || echo unset)" \
      "$(defaults read com.apple.dock static-only 2>/dev/null || echo unset)"
    if [ "$cmd" != status ]; then
      echo "usage: dock-nothing.sh [hide|show|status]" >&2
      exit 1
    fi
    ;;
esac
