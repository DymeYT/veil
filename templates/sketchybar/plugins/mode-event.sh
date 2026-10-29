#!/bin/bash
# Rift binding mode changed: show the mode name (e.g. RESIZE) beside the workspaces; hide it in the default mode.
if [ -z "$RIFT_BINDING_MODE" ] || [ "$RIFT_BINDING_MODE" = default ]; then
  /opt/homebrew/bin/sketchybar --set mode drawing=off
else
  /opt/homebrew/bin/sketchybar --set mode drawing=on label="$(printf '%s' "$RIFT_BINDING_MODE" | tr '[:lower:]' '[:upper:]')"
fi
