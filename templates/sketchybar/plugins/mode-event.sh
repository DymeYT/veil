#!/bin/bash
# Rift binding mode changed: show the mode name (e.g. RESIZE) beside the workspaces; hide it in the default mode.
# Switching apps leaves the mode, so a stray ⌥R never keeps eating typed letters (sketchybar front_app_switched).
SB=/opt/homebrew/bin/sketchybar
if [ "$SENDER" = front_app_switched ]; then
  [ "$($SB --query mode 2>/dev/null | /usr/bin/grep -o '"drawing": *"on"')" ] && "$HOME/.local/bin/rift-cli" execute binding-mode default >/dev/null 2>&1
  exit 0
fi
if [ -z "$RIFT_BINDING_MODE" ] || [ "$RIFT_BINDING_MODE" = default ]; then
  $SB --set mode drawing=off
else
  $SB --set mode drawing=on label="$(printf '%s' "$RIFT_BINDING_MODE" | tr '[:lower:]' '[:upper:]') · ESC"
fi
