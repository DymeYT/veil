#!/bin/bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAGS='@@tag_mode@@'   # text: tags are words | icons: tags are glyphs that also show the level
CASE='@@value_case@@' # upper | lower | title, for words the bar writes (WIFI, MUTE, MON 26)
CLOCK_DATE='@@clock_date@@'; CLOCK_TIME='@@clock_time@@'
cased() { case "$CASE" in upper) tr '[:lower:]' '[:upper:]' ;; lower) tr '[:upper:]' '[:lower:]' ;; *) LC_ALL=C awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[A-Za-z]+$/ && $i !~ /^(CPU|MEM|VOL|NET|VPN|LAN|WIFI)$/) $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2)) } 1' ;; esac; }  # title case leaves numbers, symbols and acronyms alone
CACHE="$HOME/Library/Caches"
METRICS="$HOME/.local/bin/veil-metrics"
unchanged() {
  local stamp old_stamp old_value
  read -r stamp 2>/dev/null < "$CACHE/veil-bar-epoch" || return 1
  {
    read -r old_stamp
    read -r old_value
  } 2>/dev/null < "$CACHE/veil-bar-$NAME"
  [[ "$stamp" = "$old_stamp" && "$1" = "$old_value" ]]
}
remember() {
  local stamp
  read -r stamp 2>/dev/null < "$CACHE/veil-bar-epoch" || return 0
  printf '%s\n' "$stamp" "$1" > "$CACHE/veil-bar-$NAME"
}
# Music and Spotify publish playback transitions through distributed
# notifications. Read their scripting dictionaries only when the panel opens
# without an event or when a control is clicked. Cider has no AppleScript
# dictionary; when enabled, media-control reads Now Playing on demand (no
# stream helper, no timer). Disable with: veil feature disable cider-bridge
music_feature_off() { [ -f "$HOME/.config/veil/generated/features/disable-$1" ]; }
music_bundle_source() {
  case "$1" in
    com.apple.Music) echo Music ;;
    com.spotify.client) echo Spotify ;;
    sh.cider.*|*.cider.*) echo Cider ;;
    *) [ -n "$1" ] && echo "$1" || echo "" ;;
  esac
}
music_sip_nowplaying() {
  # Opt-in SIP-gated helper (default off). Usable overnight as a no-op fallback.
  [ -f "$HOME/.config/veil/generated/features/enable-sip-nowplaying" ] || return 1
  # SIP+AMFI SIGKILLs the helper — skip entirely so music never pays a kill tax.
  /usr/bin/csrutil status 2>/dev/null | /usr/bin/grep -qi 'enabled' && return 1
  # After SIP off, AMFI may still SIGKILL (private entitlements). Cache that once.
  local amfi_block="$HOME/.config/veil/generated/features/.sip-nowplaying-amfi-blocked"
  [ -f "$amfi_block" ] && return 1
  local bin="$HOME/.config/veil/bin/veil-nowplaying-sip" action="${1:-}" raw ec
  [ -x "$bin" ] || return 1
  case "$action" in
    previous) "$bin" previous >/dev/null 2>&1 || true ;;
    next) "$bin" next >/dev/null 2>&1 || true ;;
    playpause) "$bin" toggle >/dev/null 2>&1 || true ;;
  esac
  raw=$("$bin" get 2>/dev/null); ec=$?
  if [ "$ec" -ne 0 ]; then
    # 137 = 128+SIGKILL — AMFI; stamp so we never re-kill on every poll.
    if [ "$ec" -eq 137 ] || [ "$ec" -gt 128 ]; then
      mkdir -p "$(dirname "$amfi_block")"
      printf 'amfi_sigkill exit=%s ts=%s\n' "$ec" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$amfi_block" 2>/dev/null || true
    fi
    return 1
  fi
  [ -n "$raw" ] && [ "$raw" != '{}' ] || return 1
  local bundle source playing title artist album
  bundle=$(jq -r '.bundleIdentifier // empty' <<<"$raw" 2>/dev/null) || return 1
  source=$(music_bundle_source "$bundle")
  [ -n "$source" ] || source="Now playing"
  playing=$(jq -r 'if (.playing == true) or ((.playbackRate // 0) > 0) then "playing" else "paused" end' <<<"$raw")
  title=$(jq -r '.title // empty' <<<"$raw")
  artist=$(jq -r '.artist // empty' <<<"$raw")
  album=$(jq -r '.album // empty' <<<"$raw")
  [ -n "$title" ] || return 1
  jq -nc --arg source "$source" --arg state "$playing" --arg title "$title" --arg artist "$artist" --arg album "$album" \
    '{source:$source, state:$state, title:$title, artist:$artist, album:$album}'
}
music_media_control() {
  music_feature_off cider-bridge && return 1
  # Prefer SIP helper only when opted in and it actually returns data; else media-control.
  local via_sip=""
  via_sip=$(music_sip_nowplaying "${1:-}") && { printf '%s\n' "$via_sip"; return 0; }
  command -v media-control >/dev/null || return 1
  local action="${1:-}" raw bundle source state title artist album playing
  case "$action" in
    previous) media-control previous-track >/dev/null 2>&1 || true ;;
    next) media-control next-track >/dev/null 2>&1 || true ;;
    playpause) media-control toggle-play-pause >/dev/null 2>&1 || true ;;
  esac
  raw=$(media-control get --no-artwork 2>/dev/null) || return 1
  [ -n "$raw" ] && [ "$raw" != null ] || return 1
  bundle=$(jq -r '.bundleIdentifier // .bundleID // empty' <<<"$raw" 2>/dev/null) || return 1
  source=$(music_bundle_source "$bundle")
  [ -n "$source" ] || source=$(jq -r '.displayName // .appName // "Now playing"' <<<"$raw")
  playing=$(jq -r 'if (.playing == true) or (.isPlaying == true) or ((.playbackRate // 0) > 0) then "playing" else "paused" end' <<<"$raw")
  title=$(jq -r '.title // .name // empty' <<<"$raw")
  artist=$(jq -r '.artist // .artistName // empty' <<<"$raw")
  album=$(jq -r '.album // .albumName // empty' <<<"$raw")
  [ -n "$title" ] || return 1
  jq -nc --arg source "$source" --arg state "$playing" --arg title "$title" --arg artist "$artist" --arg album "$album" \
    '{source:$source, state:$state, title:$title, artist:$artist, album:$album}'
}
music_snapshot() {
  # Prefer media-control / SIP helper for ALL players (incl. Music). Never open
  # an AppleScript Automation prompt just to paint the popup — that path is only
  # a last resort when Now Playing is empty and the user named Music/Spotify.
  local selected="$1" action="$2" now=""
  now=$(music_media_control "$action") || now=""
  if [ -n "$now" ] && jq -e '(.title | length) > 0' >/dev/null 2>&1 <<<"$now"; then
    printf '%s\n' "$now"
    return 0
  fi
  if [ -z "$action" ] || [ "$selected" = Cider ]; then
    printf '%s\n' '{"source":"","state":"stopped","title":"","message":"Nothing playing"}'
    return 0
  fi
  # Control-only fallback for Music/Spotify when Now Playing is empty.
  case "$selected" in
    Music|Spotify) ;;
    *) printf '%s\n' '{"source":"","state":"stopped","title":"","message":"Nothing playing"}'; return 0 ;;
  esac
  local snapshot
  snapshot=$(perl -e 'alarm 2; exec @ARGV' /usr/bin/osascript -l JavaScript - "$selected" "$action" <<'JXA'
ObjC.import("AppKit");
function run(args) {
    const players = [
        { source: "Music", id: "com.apple.Music" },
        { source: "Spotify", id: "com.spotify.client" }
    ];
    const [selected, action] = args;
    const player = players.find(p => p.source === selected);
    if (!player) return JSON.stringify({ source: "", state: "stopped", title: "" });
    const running = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(player.id);
    if (!Number(running.count)) return JSON.stringify({ source: "", state: "stopped", title: "" });
    try {
        const app = Application(ObjC.unwrap(running.objectAtIndex(0).bundleURL.path));
        switch (action) {
            case "previous": app.previousTrack(); break;
            case "next": app.nextTrack(); break;
            case "playpause": app.playpause(); break;
        }
        const state = String(app.playerState());
        if (state === "stopped") return JSON.stringify({ source: "", state: "stopped", title: "" });
        const track = app.currentTrack;
        return JSON.stringify({
            source: player.source, state,
            title: String(track.name() || ""),
            artist: String(track.artist() || ""),
            album: (function () { try { return String(track.album() || ""); } catch (_) { return ""; } })()
        });
    } catch (error) {
        return JSON.stringify({ source: "", state: "stopped", title: "", message: "Playback details unavailable." });
    }
}
JXA
) || snapshot='{"source":"","state":"stopped","title":""}'
  printf '%s\n' "$snapshot"
}
music_read() {
  player=; state=; track=; detail=; message=
  IFS=$'\x1f' read -r player state track detail message < <(jq -r '
    def line: if type == "string" then gsub("[[:cntrl:]]"; " ") else "" end;
    [(.source | line), (.state | line), (.title | line),
     ([.artist, .album] | map(line | select(length > 0)) | join(" · ")), (.message | line)]
    | join("\u001f")' <<<"$1")
}
music_draw() {
  local show=off controls=off detail_drawing=off color=0xff8794ad glyph=󰐊 toggle='Play'
  [ -z "$detail" ] || detail_drawing=on
  if [ -n "$player" ] && [ -n "$track" ] && [ "$state" != stopped ]; then controls=on; fi
  if [ "$state" = playing ] && [ -n "$track" ]; then
    show=on; color=0xff00e5ff; glyph=󰏤; toggle='Pause'
  fi
  # Soft-fail during theme reload races when the music item is briefly absent.
  sketchybar --set music label="$track" label.drawing="$show" icon.color="$color" \
    --set music.source label="${player:-Now playing}" \
    --set music.track label="${track:-${message:-Nothing playing}}" \
    --set music.detail label="$detail" drawing="$detail_drawing" \
    --set music.previous drawing="$controls" --set music.toggle drawing="$controls" icon="$glyph" label="$toggle" \
    --set music.next drawing="$controls" "$@" 2>/dev/null || return 0
}
music_panel() {
  local event="${1:-$SENDER}" cache="$CACHE/veil-bar-music"
  local player state track detail message snapshot cached source
  case "$event" in
    forced) rm -f "$cache"; return ;;
    mouse.exited.global) sketchybar --set music popup.drawing=off; return ;;
  esac
  if [[ -s "$cache" ]]; then
    read -r cached < "$cache"
    music_read "$cached"
  fi
  case "$event" in
    music_change|spotify_change)
      source=Music; [ "$event" != spotify_change ] || source=Spotify
      snapshot=$(jq -ce --arg source "$source" '
        def text: if type == "string" then . else "" end;
        {source: $source, state: (."Player State" | text | ascii_downcase), title: (.Name | text),
         artist: (.Artist | text), album: (.Album | text)}
        | select(.state == "playing" or .state == "paused" or .state == "stopped")' <<<"$INFO" 2>/dev/null) || return
      # A stale pause from the other player must not replace the active track.
      if [ -n "$player" ] && [ "$source" != "$player" ] && [ "$state" = playing ]; then
        [ "$(jq -r .state <<<"$snapshot")" = playing ] || return
      fi
      # Spotify pause payloads may omit metadata. Keep the previous track so
      # the panel can resume it without querying for every player event.
      snapshot=$(jq -c --argjson prior "${cached:-null}" '
        if .source == $prior.source and .state == "paused" and .title == "" then
          $prior + {state: .state}
        elif .state == "stopped" then
          {source: "", state: "stopped", title: "", artist: "", album: ""}
        else . end' <<<"$snapshot") || return
      ;;
    mouse.clicked)
      # Animated Veil music panel by default; SketchyBar popup is the opt-in fallback.
      if [ ! -f "$HOME/.config/veil/generated/features/enable-sketchybar-popups" ] \
         && [ ! -f "$HOME/.config/veil/generated/features/disable-animated-panels" ]; then
        "$HOME/.local/bin/veil" music-popup >/dev/null 2>&1 || true
        return
      fi
      if sketchybar --query music | jq -e '.popup.drawing == "on" or .popup.drawing == true' >/dev/null; then
        sketchybar --set music popup.drawing=off
        return
      fi
      # Always re-query on open so a Cider/Now Playing handoff is not hidden by a
      # stale Music/Spotify cache from an earlier session.
      snapshot=$(music_snapshot "" "") || snapshot="$cached"
      ;;
    previous|next|playpause)
      # Always drive controls through Now Playing — never AppleScript on open/control.
      snapshot=$(music_media_control "$event") || snapshot=$(music_snapshot "${player:-}" "$event") || return
      ;;
    *) return ;;
  esac
  [ -n "$snapshot" ] || snapshot='{"source":"","state":"stopped","title":""}'
  music_read "$snapshot"
  if [ "$event" = mouse.clicked ]; then
    music_draw --set city popup.drawing=off --set keys popup.drawing=off --set clock popup.drawing=off --set music popup.drawing=on || return
  else
    music_draw || return
  fi
  printf '%s\n' "$snapshot" > "$cache"
}

if [ "${1:-}" = music ]; then
  # `veil.sh music snapshot` → JSON for VeilPanelHost / tooling (no SketchyBar mutate).
  if [ "${2:-}" = snapshot ]; then
    music_snapshot "" ""
    exit
  fi
  music_panel "$2"
  exit
fi
case "$NAME" in
 clock)
   if [[ "$SENDER" = mouse.exited.global ]]; then exec sketchybar --set clock popup.drawing=off; fi
  # Read both fields from one timestamp so midnight cannot split the date and time.
  stamp=$(date "+$CLOCK_DATE"$'\t'"$CLOCK_TIME") || exit 0
  unchanged "$stamp" && exit 0
  if sketchybar --set "$NAME" icon="$(cased <<<"${stamp%%$'\t'*}")" label="${stamp#*$'\t'}"; then
   remember "$stamp"
  fi ;;
 battery)
  data=$(pmset -g batt) || exit 0
  if [[ ! "$data" =~ ([0-9]{1,3})% ]]; then
   # Desktops and some USB battery reports have no internal battery percentage.
   unchanged absent && exit 0
   if sketchybar --set "$NAME" drawing=off update_freq=0 updates=on; then
    remember absent
   fi
   exit 0
  fi
  value=$((10#${BASH_REMATCH[1]})); [ "$value" -le 100 ] || exit 0
  color=0xff00e5ff; label="${value}%"
  [[ "$data" == *'AC Power'* ]] && color=0xff5af7a5
  [[ "$value" -lt 20 && "$data" != *'AC Power'* ]] && color=0xffff5370
  # level glyph (Nerd Font battery 10..100, bolt when charging)
  glyphs=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹); g=${glyphs[$(( value / 10 ))]}
  [[ "$data" == *'AC Power'* ]] && g=󰂄
  glyph=()
  [ "$TAGS" != icons ] || glyph=(icon="$g")
  state="$value $color"
  unchanged "$state" && exit 0
  if sketchybar --set "$NAME" drawing=on update_freq=180 "${glyph[@]}" label="$label" icon.color="$color"; then
   remember "$state"
  fi ;;
 volume)
  # first draw has no event payload: read the current level instead of showing a placeholder
  [[ "$SENDER" == volume_change ]] || INFO=$(osascript -e 'if output muted of (get volume settings) then return 0' -e 'return output volume of (get volume settings)' 2>/dev/null)
  [[ "$INFO" =~ ^[0-9]+$ ]] || exit 0
  if [ "$INFO" = 0 ]; then label=$(echo MUTE | cased); g=󰝟; else label="${INFO}%"; g=󰕿; [ "$INFO" -gt 33 ] && g=󰖀; [ "$INFO" -gt 66 ] && g=󰕾; fi
  if [ "$TAGS" = icons ]; then sketchybar --set "$NAME" icon="$g" label="$label"; else sketchybar --set "$NAME" label="$label"; fi ;;
 net)
  # Route and hardware inventory are needed only on a network event. A tunnel
  # already identifies its own kind, so skip the hardware query in that case.
  route_data=$(route -n get default 2>/dev/null)
  iface=''
  if [[ "$route_data" =~ interface:[[:blank:]]*([[:alnum:]]+) ]]; then
   iface=${BASH_REMATCH[1]}
  fi
  # Wi-Fi notifications are unavailable on some recent macOS releases. On a
  # periodic check the interface alone is enough to rule out a visible change.
  if [ "$SENDER" = routine ] && unchanged "$iface"; then
   exit 0
  fi
  color=0xff00e5ff; ink=0xffd9f4ff
  case "$iface" in
   '') label=OFFLINE; color=0xffff5370; ink=0xffff5370; g=󰖪 ;;
   utun*|ipsec*|ppp*) label=VPN; g=󰦝 ;;
   *)
    port=$(networksetup -listallhardwareports | awk -v d="$iface" '/^Hardware Port:/{sub(/^Hardware Port: /,""); p=$0} /^Device:/{if ($2==d) {print p; exit}}')
    g=󰖩
    case "$port" in
     Wi-Fi) label=WIFI ;;
     *Ethernet*|*LAN*|Thunderbolt*) label=LAN; g=󰈀 ;;
     *iPhone*) label=PHONE ;;
     *) label=$(tr '[:lower:]' '[:upper:]' <<<"${port:-$iface}"); label=${label:0:6} ;;
    esac ;;
  esac
  glyph=()
  [ "$TAGS" != icons ] || glyph=(icon="$g")
  if sketchybar --set "$NAME" "${glyph[@]}" label="$(cased <<<"$label")" label.color="$ink" icon.color="$color"; then
   remember "$iface"
  fi ;;
 music) music_panel ;;
 app) [[ "$SENDER" == front_app_switched && "$INFO" != "Veil Search" ]] && sketchybar --set "$NAME" label="$INFO" ;;  # the launcher is an overlay, not the app you are in
 cpu)
  graph=${1:-on}; show_temp=${2:-on}
  options=()
  [ "$show_temp" = on ] || options=(--no-temperature)
  read -r cpu mem temp < <("$METRICS" "$CACHE/veil-cpu" "${options[@]}") || exit 0
  args=(--set cpu label="${cpu}%" --set memory label="${mem}G")
  if [[ "$graph" = on ]]; then
   printf -v value '%d.%02d' "$((cpu / 100))" "$((cpu % 100))"
   history="$CACHE/veil-cpu-hist"
   samples=()
   if [[ -s "$history" ]]; then
    while read -r sample; do
     [[ "$sample" =~ ^(0\.[0-9][0-9]|1\.00)$ ]] && samples+=("$sample")
    done < "$history"
   fi
   epoch=''; seeded=''
   read -r epoch 2>/dev/null < "$CACHE/veil-bar-epoch"
   read -r seeded 2>/dev/null < "$history.seeded"
   if [[ "$epoch" != "$seeded" && ${#samples[@]} -gt 0 ]]; then
    args+=(--push cpu.graph "${samples[@]}")
   fi
   args+=(--push cpu.graph "$value")
  fi
  if [[ "$show_temp" = on ]]; then
   tc=0xffd9f4ff; [[ "$temp" -ge 85 ]] && tc=0xffff5370
   temp_label='—'; [[ "$temp" -gt 0 ]] && temp_label="${temp}°"
   args+=(--set temp label="$temp_label" label.color="$tc")
  fi
  if sketchybar "${args[@]}" && [[ "$graph" = on ]]; then
   samples+=("$value")
   offset=$(( ${#samples[@]} > 34 ? ${#samples[@]} - 34 : 0 ))
   printf '%s\n' "${samples[@]:$offset}" > "$history"
   if [[ "$epoch" != "$seeded" ]]; then
    printf '%s\n' "$epoch" > "$history.seeded"
   fi
  fi ;;
 city)
  if [[ "$SENDER" == mouse.clicked ]]; then
   # Animated Veil control panel by default; SketchyBar popup when sketchybar-popups is enabled.
   if [ ! -f "$HOME/.config/veil/generated/features/enable-sketchybar-popups" ] \
      && [ ! -f "$HOME/.config/veil/generated/features/disable-animated-panels" ]; then
     "$HOME/.local/bin/veil" panel control >/dev/null 2>&1 || true
     exit 0
   fi
   # one status line, read when the panel opens: no background polling for readings that are off the bar
   # quiet mode is the user's switch (veil quiet); Reduce Motion is the system's, and is reported on its own
   quiet=OFF; [ -f "$HOME/.config/veil/generated/quiet" ] && quiet=ON
   extra=''; [ "$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)" = 1 ] && extra="$extra  ·  MOTION OFF BY SYSTEM"
   # ⌥Z pauses tiling on the focused display's space: say so, or the pause looks like a broken window manager
   rift-cli query displays 2>/dev/null | jq -e 'any(.[]; .is_active_context and (.is_active_space | not))' >/dev/null && extra="$extra  ·  TILING PAUSED"
   read -r cpu mem temp < <("$METRICS" "$CACHE/veil-cpu" --instant)
   vol=$(osascript -e 'if output muted of (get volume settings) then return "MUTE"' -e 'return (output volume of (get volume settings) as text) & "%"' 2>/dev/null)
   if route -n get default >/dev/null 2>&1; then net=ONLINE; else net=OFFLINE; fi
   t=''; [[ "${temp:-0}" -gt 0 ]] && t="  ·  TEMP ${temp}°"
   # one line: the readings always, states only when they are the exception
   state=''; [ "$net" = OFFLINE ] && state="  ·  OFFLINE"; [ "$quiet" = ON ] && state="$state  ·  QUIET"
   status="CPU ${cpu:-?}%  ·  MEM ${mem:-?}G$t  ·  VOL ${vol:-?}$state$extra"
   sketchybar --set menu.status label="$(echo "$status" | cased)" --set keys popup.drawing=off --set music popup.drawing=off --set clock popup.drawing=off --set city popup.drawing=toggle
  else
   sketchybar --set city popup.drawing=off
  fi ;;
 keys) sketchybar --set keys popup.drawing=off ;;  # mouse.exited.global: close when the pointer leaves
esac
exit 0
