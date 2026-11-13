#!/bin/bash
# Build + ad-hoc sign the SIP-gated Now Playing helper.
# Overnight: building is fine with SIP on; the helper may not receive NP under AMFI.
# After wake (SIP off): re-run this script, then: veil feature enable sip-nowplaying
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/bin/veil-nowplaying-sip}"
SDK="${SDKROOT:-}"
if [ -z "$SDK" ]; then
  for s in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
           /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
           /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk; do
    [ -d "$s" ] && SDK="$s" && break
  done
fi
SRC="$(cd "$(dirname "$0")" && pwd)/NowPlayingSip.swift"
ENT="$(cd "$(dirname "$0")" && pwd)/veil-nowplaying-sip.entitlements"
mkdir -p "$(dirname "$OUT")"
SWIFTC=(swiftc -O -module-name VeilNowPlayingSip "$SRC" -o "$OUT")
if [ -n "$SDK" ]; then
  SWIFTC+=(-sdk "$SDK")
fi
"${SWIFTC[@]}"
codesign --force --sign - --entitlements "$ENT" "$OUT"
echo "built $OUT"
"$OUT" status || true
