#!/usr/bin/env bash
# Usage: build-release-zip.sh /path/to/TubeBackdrop.app [output.zip]
set -euo pipefail
APP="${1:?path to TubeBackdrop.app}"
OUT="${2:-TubeBackdrop-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo unknown).zip}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -R "$APP" "$TMP/"
ditto -c -k --sequesterRsrc --keepParent "$TMP/$(basename "$APP")" "$OUT"
echo "Wrote $OUT"
