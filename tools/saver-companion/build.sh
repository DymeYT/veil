#!/bin/bash
# VEI-40 saver companion — theme drift overlay, never ScreenSaverEngine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/bin/veil-saver-companion}"
SRC="$(cd "$(dirname "$0")" && pwd)/SaverCompanion.swift"
mkdir -p "$(dirname "$OUT")"
swiftc -O -parse-as-library -module-name VeilSaverCompanion "$SRC" -o "$OUT"
codesign --force --sign - "$OUT"
echo "built $OUT"
echo "enable: veil feature enable saver-companion"
echo "preview: $OUT --once   (click/key dismisses; no SSE)"
