#!/bin/bash
# Remove Veil and put the pre-install settings back. Leaves Homebrew packages installed.
set -uo pipefail
NC="$HOME/.config/veil"
O="$NC/backups/original"

"$HOME/.local/bin/rift" service stop
"$HOME/.local/bin/rift" service uninstall
launchctl bootout "gui/$(id -u)/app.veil.search" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/app.veil.search.plist"
rm -rf "$HOME/Applications/Veil Search.app"
brew services stop sketchybar
brew services stop borders

g="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
cp "$g" "$g.veil.bak" 2>/dev/null   # keep edits made after install
[ -f "$O/ghostty.config.ghostty" ] && cp "$O/ghostty.config.ghostty" "$g"
[ -f "$O/cava.config" ] && cp "$O/cava.config" "$HOME/.config/cava/config"
if [ -f "$O/appearance.json" ]; then
  defaults write -g AppleAccentColor -int "$(jq -r .AppleAccentColor "$O/appearance.json")"
  defaults write -g AppleHighlightColor "$(jq -r .AppleHighlightColor "$O/appearance.json")"
fi
defaults delete -g com.apple.sound.beep.sound 2>/dev/null
# no pre-rice copies of the alert sound or pointer colours were kept, so these return to system defaults

cursor="$HOME/Library/Application Support/Cursor/User/settings.json"
if [ -f "$cursor" ]; then
  tmp=$(mktemp)
  if [ -f "$O/cursor.settings.json" ]; then
    jq --slurpfile original "$O/cursor.settings.json" '
      ["editor.fontFamily", "terminal.integrated.fontFamily", "editor.lineHeight", "editor.cursorStyle",
       "editor.cursorBlinking", "editor.minimap.enabled", "editor.renderLineHighlight",
       "workbench.activityBar.location", "workbench.editor.tabSizing", "workbench.tree.indent", "workbench.sideBar.location", "workbench.editor.showTabs", "breadcrumbs.enabled", "editor.stickyScroll.enabled", "editor.lineNumbers", "editor.wordWrap", "editor.renderWhitespace", "editor.minimap.side"] as $keys
      | reduce $keys[] as $k (. ; if ($original[0] | has($k)) then .[$k] = $original[0][$k] else del(.[$k]) end)
      | ."workbench.colorCustomizations" |= ( . // {}
          | if (($original[0]["workbench.colorCustomizations"] // {}) | has("[*Dark*]"))
            then .["[*Dark*]"] = $original[0]["workbench.colorCustomizations"]["[*Dark*]"]
            else del(.["[*Dark*]"]) end)
      | if ((."workbench.colorCustomizations" // {}) | length) == 0 then del(."workbench.colorCustomizations") else . end
    ' "$cursor" > "$tmp" && mv "$tmp" "$cursor"
  else
    jq 'del(."workbench.colorCustomizations"."[*Dark*]")
      | if ((."workbench.colorCustomizations" // {}) | length) == 0 then del(."workbench.colorCustomizations") else . end
      | del(."editor.fontFamily", ."terminal.integrated.fontFamily", ."editor.lineHeight", ."editor.cursorStyle",
            ."editor.cursorBlinking", ."editor.minimap.enabled", ."editor.renderLineHighlight",
            ."workbench.activityBar.location", ."workbench.editor.tabSizing", ."workbench.tree.indent", ."workbench.sideBar.location", ."workbench.editor.showTabs", ."breadcrumbs.enabled", ."editor.stickyScroll.enabled", ."editor.lineNumbers", ."editor.wordWrap", ."editor.renderWhitespace", ."editor.minimap.side")' \
      "$cursor" > "$tmp" && mv "$tmp" "$cursor"
  fi
fi
jq -r '.vaults[].path' "$HOME/Library/Application Support/obsidian/obsidian.json" 2>/dev/null | while IFS= read -r vault; do
  rm -f "$vault/.obsidian/snippets/veil.css"
  a="$vault/.obsidian/appearance.json"
  [ -f "$a" ] && tmp=$(mktemp) && jq '.enabledCssSnippets -= ["veil"]' "$a" > "$tmp" && mv "$tmp" "$a"
done

# files only the rice creates; the shared configs below have no pre-rice originals, so they stay and are listed
rm -f "$HOME/.config/nvim/lua/plugins/veil.lua" "$HOME/.config/btop/themes/veil.theme"
[ -f "$HOME/.config/btop/btop.conf" ] && sed -i '' 's/^color_theme = .*/color_theme = "Default"/' "$HOME/.config/btop/btop.conf"
for b in veil veil-theme veil-metrics; do rm -f "$HOME/.local/bin/$b"; done
# Veil Search's own data: preferences (search history, usage ranking, pins, cached rates) and support folder
defaults delete app.veil.search 2>/dev/null
rm -rf "$HOME/Library/Application Support/app.veil.search"
echo "Left in place (no pre-rice copies existed): ~/.config/{starship.toml,fastfetch,btop/btop.conf,rift,sketchybar,borders}."
echo "Removed. Delete the 'Veil theme colors' lines from ~/.zshrc, then log out and back in."
