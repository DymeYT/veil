#!/bin/bash
# Build + ad-hoc sign the SIP-gated Now Playing helper.
# Default entitlements: library-validation bypass only (runs under SIP-off without AMFI boot-arg).
# Optional: VEIL_SIP_PRIVATE_ENTITLEMENTS=1 ./build.sh  → private MediaRemote entitlement
#   (requires amfi_get_out_of_my_way=1 or AMFI will SIGKILL).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/bin/veil-nowplaying-sip}"
SDK="${SDKROOT:-}"
if [ -z "$SDK" ]; then
  for s in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
           /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
           /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk; do
    [ -d "$s" ] && SDK="$s" && break
  done
fi
SRC="$HERE/NowPlayingSip.swift"
if [ "${VEIL_SIP_PRIVATE_ENTITLEMENTS:-0}" = 1 ]; then
  ENT="$HERE/veil-nowplaying-sip.private.entitlements"
  echo "signing with PRIVATE MediaRemote entitlements (needs AMFI relaxed)"
else
  ENT="$HERE/veil-nowplaying-sip.entitlements"
fi
mkdir -p "$(dirname "$OUT")"
SWIFTC=(swiftc -O -module-name VeilNowPlayingSip "$SRC" -o "$OUT")
if [ -n "$SDK" ]; then
  SWIFTC+=(-sdk "$SDK")
fi
"${SWIFTC[@]}"
codesign --force --sign - --entitlements "$ENT" "$OUT"
echo "built $OUT"
rm -f "$ROOT/generated/features/.sip-nowplaying-amfi-blocked"
if /usr/bin/csrutil status 2>/dev/null | /usr/bin/grep -qi 'enabled'; then
  echo "sip=enabled — helper may still be limited; after csrutil disable expect: sip=disabled mediaremote=ok"
else
  if "$OUT" status; then
    :
  else
    ec=$?
    echo "status failed (exit $ec). If Killed:9, you signed with private entitlements under hard AMFI — rebuild without VEIL_SIP_PRIVATE_ENTITLEMENTS=1."
  fi
fi
