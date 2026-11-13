#!/bin/bash
# Safe saver preview — never ScreenSaverEngine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$ROOT/bin/veil-saver-preview"
SDK="${SDKROOT:-}"
if [ ! -x "$BIN" ] || [ "$(dirname "$0")/SaverPreview.swift" -nt "$BIN" ]; then
  if [ -z "$SDK" ]; then
    for s in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
             /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
             /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk; do
      [ -d "$s" ] && SDK="$s" && break
    done
  fi
  ARGS=(swiftc -O -parse-as-library "$(dirname "$0")/SaverPreview.swift" -o "$BIN" -framework AppKit -framework QuartzCore)
  if [ -n "$SDK" ]; then
    export SDKROOT="$SDK"
  fi
  "${ARGS[@]}"
  codesign --force --sign - "$BIN" >/dev/null
fi
export VEIL_ROOT="$ROOT"
exec "$BIN" "$@"
