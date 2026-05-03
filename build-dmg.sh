#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
APP_NAME="MacExplorer"
APP_DIR="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_DIR="build/dmg"
ENTITLEMENTS="MacExplorer/MacExplorer.entitlements"

echo "=== Building ${APP_NAME} v${VERSION} ==="

# 1. Build release binary
echo "Building release binary..."
swift build -c release 2>&1 | tail -5

# 2. Create .app bundle
echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp .build/arm64-apple-macosx/release/${APP_NAME} "$APP_DIR/Contents/MacOS/${APP_NAME}"

# Info.plist with version
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.macexplorer.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 3. Code sign
echo "Code signing..."
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR"

# 4. Create DMG
echo "Creating DMG..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"

# Create a symlink to /Applications for drag-install
ln -s /Applications "$DMG_DIR/Applications"

rm -f "build/${DMG_NAME}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "build/${DMG_NAME}"

# Cleanup staging
rm -rf "$DMG_DIR"

echo ""
echo "=== Build complete! ==="
echo "  App:  ${APP_DIR}"
echo "  DMG:  build/${DMG_NAME}"
echo "  Size: $(du -h "build/${DMG_NAME}" | cut -f1)"
echo ""
echo "To create a GitHub release:"
echo "  gh release create v${VERSION} build/${DMG_NAME} --title \"v${VERSION}\" --notes \"MacExplorer v${VERSION}\""
