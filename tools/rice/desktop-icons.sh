#!/bin/bash
# Finder desktop-icon guidance for Nothing rice (Glyph field).
# hide  — no desktop icons (screenshot-clean)
# show  — restore volume icons + CreateDesktop
# status — print current defaults
set -euo pipefail

cmd="${1:-status}"

case "$cmd" in
  hide)
    defaults write com.apple.finder CreateDesktop -bool false
    defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
    defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
    defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
    defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
    killall Finder >/dev/null 2>&1 || true
    echo "Finder desktop icons hidden (Nothing Glyph field)."
    echo "Tip: keep Desktop files in ~/Desktop; they stay in Finder, just not on the wall."
    ;;
  show)
    defaults write com.apple.finder CreateDesktop -bool true
    defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
    defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
    defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
    killall Finder >/dev/null 2>&1 || true
    echo "Finder desktop icons shown."
    ;;
  status|*)
    printf 'CreateDesktop=%s\n' "$(defaults read com.apple.finder CreateDesktop 2>/dev/null || echo unset)"
    printf 'ShowExternalHardDrivesOnDesktop=%s\n' "$(defaults read com.apple.finder ShowExternalHardDrivesOnDesktop 2>/dev/null || echo unset)"
    printf 'ShowHardDrivesOnDesktop=%s\n' "$(defaults read com.apple.finder ShowHardDrivesOnDesktop 2>/dev/null || echo unset)"
    printf 'ShowRemovableMediaOnDesktop=%s\n' "$(defaults read com.apple.finder ShowRemovableMediaOnDesktop 2>/dev/null || echo unset)"
    printf 'ShowMountedServersOnDesktop=%s\n' "$(defaults read com.apple.finder ShowMountedServersOnDesktop 2>/dev/null || echo unset)"
    if [ "$cmd" != status ]; then
      echo "usage: desktop-icons.sh [hide|show|status]" >&2
      exit 1
    fi
    ;;
esac
