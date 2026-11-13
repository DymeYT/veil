#!/bin/bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Disable with: veil feature disable clock-calendar
if [ -f "$HOME/.config/veil/generated/features/disable-clock-calendar" ]; then
  exec sketchybar --set clock popup.drawing=off
fi

case "${1:-}" in
    close) exec sketchybar --set clock popup.drawing=off ;;
    open-calendar)
        sketchybar --set clock popup.drawing=off
        exec /usr/bin/open -a Calendar
        ;;
    toggle) ;;
    *) exit 0 ;;
esac

# Build seven aligned columns once, on click. No calendar permissions or background work.
IFS=' ' read -r year month day first days < <(/usr/bin/awk -v stamp="$(date '+%Y %m %d %w')" '
    BEGIN {
        split(stamp, t, " ")
        y=t[1]+0; m=t[2]+0; d=t[3]+0; weekday=t[4]+0
        split("31 28 31 30 31 30 31 31 30 31 30 31", month_days, " ")
        leap=(y%4==0 && (y%100!=0 || y%400==0))
        print y, m, d, (weekday-(d-1)%7+7)%7, month_days[m]+(m==2 && leap)
    }')
[[ -n "$days" ]] || exit 1
args=(--set calendar.month "label=$(date '+%B %Y')")
for ((week=0; week<6; week++)); do
    line=''
    for ((column=0; column<7; column++)); do
        date_number=$((week*7+column-first+1))
        if (( date_number < 1 || date_number > days )); then cell='    '
        elif (( date_number == day )); then printf -v cell '[%2d]' "$date_number"
        else printf -v cell ' %2d ' "$date_number"
        fi
        line+="$cell"
    done
    drawing=on
    (( week*7-first+1 > days )) && drawing=off
    args+=(--set "calendar.week.$week" "label=$line" "drawing=$drawing")
done
exec sketchybar "${args[@]}" --set city popup.drawing=off --set music popup.drawing=off --set keys popup.drawing=off --set clock popup.drawing=toggle
