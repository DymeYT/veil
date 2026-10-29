#!/bin/bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAGS='@@tag_mode@@'   # text: tags are words | icons: tags are glyphs that also show the level
CASE='@@value_case@@' # upper | lower | title, for words the bar writes (WIFI, MUTE, MON 26)
CLOCK_DATE='@@clock_date@@'; CLOCK_TIME='@@clock_time@@'
cased() { case "$CASE" in upper) tr '[:lower:]' '[:upper:]' ;; lower) tr '[:upper:]' '[:lower:]' ;; *) awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2)) } 1' ;; esac; }
case "$NAME" in
 clock) sketchybar --set "$NAME" icon="$(date "+$CLOCK_DATE" | cased)" label="$(date "+$CLOCK_TIME")" ;;
 battery)
  data=$(pmset -g batt); percent=$(printf '%s' "$data" | /usr/bin/grep -Eo '[0-9]+%' | head -1)
  color=0xff00e5ff; label="$percent"
  [[ "$data" == *'AC Power'* ]] && color=0xff5af7a5
  value=${percent%%%}; [[ -n "$value" && "$value" -lt 20 && "$data" != *'AC Power'* ]] && color=0xffff5370
  # level glyph (Nerd Font battery 10..100, bolt when charging)
  glyphs=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹); g=${glyphs[$(( ${value:-0} / 10 ))]}
  [[ "$data" == *'AC Power'* ]] && g=󰂄
  if [ "$TAGS" = icons ]; then sketchybar --set "$NAME" icon="$g" label="$label" icon.color="$color"
  else sketchybar --set "$NAME" label="$label" icon.color="$color"; fi ;;
 volume)
  # first draw has no event payload: read the current level instead of showing a placeholder
  [[ "$SENDER" == volume_change ]] || INFO=$(osascript -e 'if output muted of (get volume settings) then return 0' -e 'return output volume of (get volume settings)' 2>/dev/null)
  [[ "$INFO" =~ ^[0-9]+$ ]] || exit 0
  if [ "$INFO" = 0 ]; then label=$(echo MUTE | cased); g=󰝟; else label="${INFO}%"; g=󰕿; [ "$INFO" -gt 33 ] && g=󰖀; [ "$INFO" -gt 66 ] && g=󰕾; fi
  if [ "$TAGS" = icons ]; then sketchybar --set "$NAME" icon="$g" label="$label"; else sketchybar --set "$NAME" label="$label"; fi ;;
 net)
  # label = kind of the default route: WIFI, LAN, VPN (utun, e.g. Mullvad) or the port name
  if iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}') && [[ -n "$iface" ]]; then
   port=$(networksetup -listallhardwareports | awk -v d="$iface" '/^Hardware Port:/{sub(/^Hardware Port: /,""); p=$0} /^Device:/{if ($2==d) print p}')
   case "$iface:$port" in
    utun*|ipsec*|ppp*) label=VPN ;; *:Wi-Fi) label=WIFI ;; *:*Ethernet*|*:*LAN*|*:Thunderbolt*) label=LAN ;; *:iPhone*) label=PHONE ;;
    *) label=$(printf '%s' "${port:-$iface}" | tr '[:lower:]' '[:upper:]' | cut -c1-6) ;;
   esac
   g=󰖩; [ "$label" = LAN ] && g=󰈀; [ "$label" = VPN ] && g=󰦝
   [ "$TAGS" = icons ] && sketchybar --set "$NAME" icon="$g"
   sketchybar --set "$NAME" label="$(echo "$label" | cased)" label.color=0xffd9f4ff icon.color=0xff00e5ff
  else
   [ "$TAGS" = icons ] && sketchybar --set "$NAME" icon=󰖪
   sketchybar --set "$NAME" label="$(echo OFFLINE | cased)" label.color=0xffff5370 icon.color=0xffff5370
  fi ;;
 music)
  # shortcut: only updates on player notifications, so a track already playing at bar start shows after the next play/pause/skip
  state=$(jq -r '."Player State" // empty' <<<"$INFO" 2>/dev/null)
  if [[ "$state" == Playing ]]; then
   sketchybar --set "$NAME" drawing=on label="$(jq -r '[.Artist, .Name] | map(select(. != null)) | join(" - ")' <<<"$INFO")"
  else
   sketchybar --set "$NAME" drawing=off
  fi ;;
 app) [[ "$SENDER" == front_app_switched && "$INFO" != "Veil Search" ]] && sketchybar --set "$NAME" label="$INFO" ;;  # the launcher is an overlay, not the app you are in
 cpu)
  read -r cpu mem < <("$HOME/.local/bin/veil-metrics" "$HOME/Library/Caches/veil-cpu")
  [[ -n "$cpu" ]] && sketchybar --set cpu label="${cpu}%" --set memory label="${mem}G" --push cpu.graph "$(printf '%d.%02d' $((cpu / 100)) $((cpu % 100)))" ;;
 city)
  if [[ "$SENDER" == mouse.clicked ]]; then
   # one status line, read when the panel opens: no background polling for readings that are off the bar
   anim=$(rift-cli execute config get 2>/dev/null | jq -r '.settings.animate')
   quiet=OFF; [ "$anim" = false ] && quiet=ON
   read -r cpu mem < <("$HOME/.local/bin/veil-metrics" "$HOME/Library/Caches/veil-cpu")
   vol=$(osascript -e 'if output muted of (get volume settings) then return "MUTE"' -e 'return (output volume of (get volume settings) as text) & "%"' 2>/dev/null)
   if route -n get default >/dev/null 2>&1; then net=ONLINE; else net=OFFLINE; fi
   status="CPU ${cpu:-?}%  ·  MEM ${mem:-?}G  ·  VOL ${vol:-?}  ·  $net  ·  QUIET $quiet"
   sketchybar --set menu.status label="$(echo "$status" | cased)" --set city popup.drawing=toggle
  else
   sketchybar --set city popup.drawing=off
  fi ;;
 keys) sketchybar --set keys popup.drawing=off ;;  # mouse.exited.global: close when the pointer leaves
esac
exit 0
