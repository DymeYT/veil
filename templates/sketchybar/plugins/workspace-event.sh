#!/bin/bash
# Rift workspace/window events: draw the active, occupied and empty workspaces in the theme's style.
# One query and one sketchybar call per event; widths stay fixed so the bar never shifts.
# Workspace switches redraw at once. windows_changed comes in bursts while windows move, and only changes which
# workspaces are occupied, so only the last event of a 150 ms burst queries Rift and redraws.
if [ "$RIFT_EVENT_TYPE" = windows_changed ]; then
  tok="${TMPDIR:-/tmp}/veil-windows-event"; me="$$"
  echo "$me" > "$tok"; sleep 0.15; [ "$(cat "$tok" 2>/dev/null)" = "$me" ] || exit 0
fi
names=(@@ws@@)
STYLE='@@ws_style@@'
THEME='@@theme_id@@'
WS_RADIUS='@@ws_radius@@'
lines=(@@ws_colors@@)      # bullet style: one color per workspace (subway lines)
roman=(I II III IV V)
kanji=(一 二 三 四 五)
bullets=(1 4 A N 7)    # real MTA lines in each bullet's color: 1 red, 4 green, A blue, N yellow, 7 purple
args=()
while IFS=$'\t' read -r i active count; do
  [ "$i" -ge 0 ] 2>/dev/null && [ "$i" -le 4 ] || continue
  count=${count:-0}; n=${names[$i]}; s="ws.$i"
  if [ "$active" = true ]; then state=active; elif [ "$count" -gt 0 ]; then state=busy; else state=empty; fi
  case "$STYLE" in
    pill|slot)
      dot='  '; [ "$count" -gt 0 ] && dot=' •'
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
    diamond)  # glyph with a small numeral, so ⌥N is findable without counting
      case $state in
        active) args+=(--set "$s" icon=◆ icon.color=0xff00e5ff label="$((i+1))" label.color=0xffd9f4ff background.drawing=off) ;;
        busy) args+=(--set "$s" icon=◈ icon.color=0xffd9f4ff label="$((i+1))" label.color=0xff8794ad background.drawing=off) ;;
        empty) args+=(--set "$s" icon=◇ icon.color=0xff76849c label="$((i+1))" label.color=0xff8794ad background.drawing=off) ;;
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
        empty) args+=(--set "$s" icon=● icon.color=0x4076849c label="$n" label.drawing=on label.color=0xff8794ad background.drawing=off) ;;
      esac ;;
  esac
done < <("$HOME/.local/bin/rift-cli" query workspaces 2>/dev/null | /usr/bin/jq -r '.[] | [.index, .is_active, .window_count] | @tsv')
[ ${#args[@]} -gt 0 ] && /opt/homebrew/bin/sketchybar "${args[@]}"
exit 0
