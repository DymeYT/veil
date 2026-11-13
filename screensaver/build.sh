#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
destination="${1:-"$source_dir/../generated"}"
veil_root="${2:-"$HOME/.config/veil"}"
mkdir -p "$destination"
staging="$(mktemp -d "${TMPDIR:-/tmp}/veil-saver.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/Veil.saver"
contents="$bundle/Contents"
resources="$contents/Resources"
mkdir -p "$contents/MacOS" "$resources"
cp -X "$source_dir/Info.plist" "$contents/Info.plist"

# The signed local bundle carries a snapshot for macOS hosts that cannot read outside their sandbox.
if [ -r "$veil_root/generated/launcher.json" ]; then
    cp -X "$veil_root/generated/launcher.json" "$resources/appearance.json"
fi
if [ -f "$veil_root/current" ]; then
    theme_id="$(<"$veil_root/current")"
    case "$theme_id" in
        ""|*[!a-z0-9-]*) ;;
        *)
            art="$veil_root/art/$theme_id.jpg"
            [ ! -f "$art" ] || cp -X "$art" "$resources/"
            ;;
    esac
fi

swiftc -module-cache-path "$staging/module-cache" -O -emit-library -module-name Veil -framework AppKit -framework ScreenSaver \
    "$source_dir/Veil.swift" -o "$contents/MacOS/Veil"
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"

if [ -e "$destination/Veil.saver" ]; then
    mv "$destination/Veil.saver" "$staging/previous.saver"
fi
if ! mv "$bundle" "$destination/Veil.saver"; then
    if [ -e "$staging/previous.saver" ]; then
        mv "$staging/previous.saver" "$destination/Veil.saver"
    fi
    exit 1
fi
printf '%s\n' "$destination/Veil.saver"
