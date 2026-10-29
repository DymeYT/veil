#!/bin/bash
# @veil title: Copy IP Address
# @veil icon: network
# Copies the Mac's local IP address and shows a notification.
ip=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
printf '%s' "$ip" | pbcopy
osascript -e "display notification \"$ip copied\" with title \"IP address\""
