#!/bin/bash
# Rift workspace/window events: draw the active, occupied and empty workspaces in the theme's style.
# Let the last window event in a burst refresh occupancy. A workspace switch updates
# immediately and supersedes an older window refresh, even if its Rift query is in flight.
cache="$HOME/Library/Caches/veil-workspaces"
token="$cache.event"
printf '%s\n' "$$" > "$token" || exit 0
[ "$RIFT_EVENT_TYPE" != windows_changed ] || sleep 0.12
read -r latest < "$token"
[ "$latest" = "$$" ] || exit 0

RIFT="$HOME/.local/bin/rift-cli"
# Cache CLI capability, which stays valid even if Rift is starting up or asleep.
# A newer installed CLI invalidates the probe.
if [[ "$RIFT" -nt "$cache.query" || ! -f "$cache.query" ]]; then
  query=workspaces
  if "$RIFT" query workspace-summary --help >/dev/null 2>&1; then
    query=workspace-summary
  fi
  printf '%s\n' "$query" > "$cache.query"
else
  read -r query < "$cache.query"
  [[ "$query" = workspace-summary ]] || query=workspaces
fi
rows=$("$RIFT" query "$query" 2>/dev/null) || exit 0
rows=$(/usr/bin/jq -r '.[] | [.index, (if .is_active then (if .window_count > 0 then "active-busy" else "active" end) elif .window_count > 0 then "busy" else "empty" end)] | @tsv' <<<"$rows") || exit 0
read -r latest < "$token"
[ "$latest" = "$$" ] || exit 0

# SketchyBar starts with blank items after a reload. Discard the previous render
# state when its configuration has a new epoch, and repaint without animation.
epoch=''
read -r epoch 2>/dev/null < "$HOME/Library/Caches/veil-bar-epoch"
previous=()
if [[ -s "$cache" ]]; then
  {
    read -r prior_epoch
    if [[ "$epoch" = "$prior_epoch" ]]; then
      read -r -a previous
    fi
  } < "$cache"
fi
STYLE='@@ws_style@@'
next=(empty empty empty empty empty)
while IFS=$'\t' read -r i state; do
  case "$STYLE:$state" in
    pill:*|slot:*) ;;
    *:active-busy) state=active ;;
  esac
  case "$i:$state" in [0-4]:active|[0-4]:active-busy|[0-4]:busy|[0-4]:empty) next[$i]=$state ;; esac
done <<<"$rows"

names=(@@ws@@)
THEME='@@theme_id@@'
WS_RADIUS='@@ws_radius@@'
lines=(@@ws_colors@@)      # bullet style: one color per workspace (subway lines)
roman=(I II III IV V)
kanji=(一 二 三 四 五)
bullets=(1 4 A N 7)    # real MTA lines in each bullet's color: 1 red, 4 green, A blue, N yellow, 7 purple
args=()
for i in 0 1 2 3 4; do
  state=${next[$i]}; n=${names[$i]}; s="ws.$i"
  [ "$state" != "${previous[$i]}" ] || continue
  occupied=false
  case "$state" in
    busy) occupied=true ;;
    active-busy) occupied=true; state=active ;;
  esac
  case "$STYLE" in
    pill|slot)
      dot='  '; [ "$occupied" = false ] || dot=' •'
      num="0$((i+1))"; [ "$STYLE" = slot ] && num="$((i+1))"
      # Field-desk (Paradis) and field-guide (Guidance) tabs are names; the factory keeps numbered shortcut slots.
      case "$THEME" in paradis|elden-ring) num='' ;; esac
      base=(icon="$num" label="$n$dot" background.corner_radius="$WS_RADIUS")
      if [ "$STYLE" = slot ]; then
        case $state in
          active) args+=(--set "$s" "${base[@]}" background.drawing=on background.color=0xff00e5ff background.border_width=1 background.border_color=0xff00e5ff icon.color=0xff070a12 label.color=0xff070a12) ;;
          busy) args+=(--set "$s" "${base[@]}" background.drawing=on background.color=0xff151b2d background.border_width=1 background.border_color=0xff334563 icon.color=0xff8794ad label.color=0xffd9f4ff) ;;
          empty) args+=(--set "$s" "${base[@]}" background.drawing=on background.color=0xff151b2d background.border_width=1 background.border_color=0xff26324a icon.color=0xff76849c label.color=0xff8794ad) ;;
        esac
      else
        case $state in
          active) args+=(--set "$s" "${base[@]}" background.drawing=on background.color=0xff182e3d icon.color=0xff00e5ff label.color=0xff00e5ff) ;;
          busy) args+=(--set "$s" "${base[@]}" background.drawing=off icon.color=0xff8794ad label.color=0xffd9f4ff) ;;
          empty) args+=(--set "$s" "${base[@]}" background.drawing=off icon.color=0xff76849c label.color=0xff8794ad) ;;
        esac
      fi ;;
    underline)  # roman numeral + name, a thread under the active one
      num="${roman[$i]}"; case "$THEME" in pharloom|dark-souls-3) num='' ;; esac   # names only, a thread under the active one
      base=(icon="$num" label="$n" background.height=2 background.y_offset=-11 background.corner_radius=1 background.color=0xff00e5ff)
      case $state in
        active) args+=(--set "$s" "${base[@]}" background.drawing=on icon.color=0xfffcee09 label.color=0xffffffff) ;;
        busy) args+=(--set "$s" "${base[@]}" background.drawing=off icon.color=0xff8794ad label.color=0xffd9f4ff) ;;
        empty) args+=(--set "$s" "${base[@]}" background.drawing=off icon.color=0xff76849c label.color=0xff8794ad) ;;
      esac ;;
    rule)  # corporate tabs: names only, a red rule over the active one
      base=(label="$n" background.height=2 background.y_offset=12 background.corner_radius=0 background.color=0xff00e5ff)
      case $state in
        active) args+=(--set "$s" "${base[@]}" background.drawing=on label.color=0xffffffff) ;;
        busy) args+=(--set "$s" "${base[@]}" background.drawing=off label.color=0xffd9f4ff) ;;
        empty) args+=(--set "$s" "${base[@]}" background.drawing=off label.color=0xff8794ad) ;;
      esac ;;
    diamond)  # diamond glyph + workspace NAME (not 1–5); position still maps to ⌥N
      case $state in
        active) args+=(--set "$s" icon=◆ icon.color=0xff00e5ff label="$n" label.color=0xffd9f4ff background.drawing=off) ;;
        busy) args+=(--set "$s" icon=◈ icon.color=0xffd9f4ff label="$n" label.color=0xff8794ad background.drawing=off) ;;
        empty) args+=(--set "$s" icon=◇ icon.color=0xff76849c label="$n" label.color=0xff8794ad background.drawing=off) ;;
      esac ;;
    bracket)  # typewriter: plain type, the active one struck in ink on a plate
      w=(label.width=$(( (${#n} + 2) * 8 )) label.align=center background.corner_radius=0 background.border_width=0)
      case $state in
        active) args+=(--set "$s" "${w[@]}" label="$n" label.color=0xff070a12 background.drawing=on background.color=0xff00e5ff) ;;
        busy) args+=(--set "$s" "${w[@]}" label="$n" label.color=0xffd9f4ff background.drawing=off) ;;
        empty) args+=(--set "$s" "${w[@]}" label="$n" label.color=0xff8794ad background.drawing=off) ;;
      esac ;;
    kanji)  # kanji numeral + name; the active one in the accent
      base=(icon="${kanji[$i]}" label="$n" background.drawing=off)
      case $state in
        active) args+=(--set "$s" "${base[@]}" icon.color=0xff00e5ff label.color=0xffffffff) ;;
        busy) args+=(--set "$s" "${base[@]}" icon.color=0xff8794ad label.color=0xffd9f4ff) ;;
        empty) args+=(--set "$s" "${base[@]}" icon.color=0xff76849c label.color=0xff8794ad) ;;
      esac ;;
    bullet)  # subway line bullets
      c=${lines[$i]}; b=${bullets[$i]}; ink=0xffffffff; [ "$b" = N ] && ink=0xff070a12
      case $state in
        active) args+=(--set "$s" icon="$b" label="$n" icon.background.color=0xff$c icon.color=$ink label.color=0xffffffff background.drawing=off) ;;
        busy) args+=(--set "$s" icon="$b" label="$n" icon.background.color=0x99$c icon.color=$ink label.color=0xff8794ad background.drawing=off) ;;
        empty) args+=(--set "$s" icon="$b" label="$n" icon.background.color=0x55$c icon.color=$ink label.color=0xff8794ad background.drawing=off) ;;
      esac ;;
    dot)  # one ● glyph at one weight; state is carried by colour alone (mixed ◉/○ glyphs render at uneven sizes)
      case $state in
        active) args+=(--set "$s" icon=● icon.color=0xff00e5ff label="$n" label.drawing=on label.color=0xffffffff background.drawing=off) ;;
        busy) args+=(--set "$s" icon=● icon.color=0xb38794ad label="$n" label.drawing=on label.color=0xffd9f4ff background.drawing=off) ;;
        empty) args+=(--set "$s" icon=● icon.color=0x4076849c label="$n" label.drawing=on label.color=0xccd9f4ff background.drawing=off) ;;
      esac ;;
  esac
done
[ ${#args[@]} -gt 0 ] || exit 0
read -r latest < "$token"
[ "$latest" = "$$" ] || exit 0
motion=()
if [ '@@system_motion@@' = true ] && [ ${#previous[@]} -gt 0 ] && [ ! -f "$HOME/.config/veil/generated/quiet" ]; then
  motion=(--animate tanh 9)
fi
if /opt/homebrew/bin/sketchybar "${motion[@]}" "${args[@]}"; then
  printf '%s\n' "$epoch" "${next[*]}" > "$cache"
fi
