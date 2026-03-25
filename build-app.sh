#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="TubeBackdrop.app"
BIN=".build/release/TubeBackdrop"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/TubeBackdrop"
cp Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/TubeBackdrop"

echo "Built $APP"
echo ""
echo "Prerequisite: brew install yt-dlp ffmpeg"
echo "Open the app: open \"$APP\""
echo "Or run CLI: $BIN"
