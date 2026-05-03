#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_DIR="build/MacExplorer.app"
BINARY="$APP_DIR/Contents/MacOS/MacExplorer"
ENTITLEMENTS="MacExplorer/MacExplorer.entitlements"

echo "Building..."
swift build 2>&1 | tail -3

echo "Packaging app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
cp .build/arm64-apple-macosx/debug/MacExplorer "$BINARY"

echo "Code signing with entitlements..."
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR"

echo "Launching..."
open "$APP_DIR"
echo "Done!"
