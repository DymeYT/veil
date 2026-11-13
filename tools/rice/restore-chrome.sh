#!/bin/bash
# Restore Finder chrome saved by apply-chrome.sh. Never writes com.apple.dock (preference lock).
set -euo pipefail

V="${VEIL_ROOT:-$HOME/.config/veil}"
STATE="$V/generated/rice-chrome.json"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
log() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }

[ -f "$STATE" ] || { echo "no rice backup at $STATE" >&2; exit 1; }

python3 - "$STATE" <<'PY'
import json, subprocess, sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())

def write(domain, key, raw):
    if raw is None:
        return
    if raw in ("0", "1", "true", "false"):
        val = "true" if raw in ("1", "true") else "false"
        subprocess.run(["defaults", "write", domain, key, "-bool", val], check=False)
        return
    if raw.isdigit() or (raw.startswith("-") and raw[1:].isdigit()):
        subprocess.run(["defaults", "write", domain, key, "-int", raw], check=False)
        return
    subprocess.run(["defaults", "write", domain, key, "-string", raw], check=False)

# Preference lock: ignore any legacy dock block from v1 backups.
if isinstance(data.get("dock"), dict):
    print("restore-chrome: skipping legacy dock backup (preference lock)", file=sys.stderr)

for k, v in data.get("finder", {}).items():
    write("com.apple.finder", k, v)
PY

killall Finder >/dev/null 2>&1 || true
rm -f "$V/generated/rice-wall-lock"
log "restored Finder from $STATE (Dock untouched)"
