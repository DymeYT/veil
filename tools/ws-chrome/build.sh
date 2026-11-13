#!/bin/bash
# VEI-41 window-server chrome helper (soft-signed; flag default off).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/bin/veil-ws-chrome}"
SRC="$(cd "$(dirname "$0")" && pwd)/WsChrome.swift"
mkdir -p "$(dirname "$OUT")"
swiftc -O -parse-as-library -module-name VeilWsChrome "$SRC" -o "$OUT"
codesign --force --sign - "$OUT"
echo "built $OUT"
echo "enable: veil feature enable ws-chrome   # or: $OUT enable"
echo "disable: veil feature disable ws-chrome"
