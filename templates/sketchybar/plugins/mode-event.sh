#!/bin/bash
# Keep a mode indicator until Rift exits the mode. A mode left on for a while
# is dropped on app switch so it cannot keep intercepting normal typing.
SB=/opt/homebrew/bin/sketchybar
since="$HOME/Library/Caches/veil-mode-since"
if [ "$SENDER" = front_app_switched ]; then
  [ -s "$since" ] || exit 0
  read -r started < "$since"
  [[ "$started" =~ ^[0-9]+$ ]] || exit 0
  [ $(( $(date +%s) - started )) -lt 15 ] || exec "$HOME/.local/bin/rift-cli" execute binding-mode default
  exit 0
fi
mode="$RIFT_BINDING_MODE"
if [ "$SENDER" = forced ]; then
  mode=$("$HOME/.local/bin/rift-cli" query binding-mode 2>/dev/null) || exit 0
  mode=${mode#\"}; mode=${mode%\"}
fi
if [ -z "$mode" ] || [ "$mode" = default ]; then
  if [ -f "$since" ]; then
    : > "$since"
  fi
  exec "$SB" --set mode drawing=off
fi
[ "$SENDER" = forced ] && [ -s "$since" ] || date +%s > "$since"
label=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
exec "$SB" --set mode drawing=on label="$label · ESC"
