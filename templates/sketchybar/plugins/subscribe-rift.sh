#!/bin/bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin"
rift-cli subscribe cli --event workspace_changed --command /bin/bash --args "$HOME/.config/sketchybar/plugins/workspace-event.sh"
rift-cli subscribe cli --event windows_changed --command /bin/bash --args "$HOME/.config/sketchybar/plugins/workspace-event.sh"
rift-cli subscribe cli --event binding_mode_changed --command /bin/bash --args "$HOME/.config/sketchybar/plugins/mode-event.sh"
