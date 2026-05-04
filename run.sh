#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_DIR="/Applications/MacExplorer.app"
ENTITLEMENTS="MacExplorer/MacExplorer.entitlements"

echo "Building..."
swift build 2>&1 | tail -3

echo "Deploying to /Applications..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp .build/arm64-apple-macosx/debug/MacExplorer "$APP_DIR/Contents/MacOS/MacExplorer"
cp MacExplorer/Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null || true

# Write Info.plist (only if missing or needs update)
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacExplorer</string>
    <key>CFBundleIdentifier</key>
    <string>com.macexplorer.app</string>
    <key>CFBundleName</key>
    <string>MacExplorer</string>
    <key>CFBundleDisplayName</key>
    <string>MacExplorer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Folder</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.folder</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "Code signing with entitlements..."
xattr -cr "$APP_DIR" 2>/dev/null
codesign --force --sign "MacExplorer Dev" --entitlements "$ENTITLEMENTS" "$APP_DIR"

echo "Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR"

echo "Launching..."
# Kill any existing instance first so the new binary is loaded
pkill -x MacExplorer 2>/dev/null || true
sleep 0.5
open "$APP_DIR"
echo "Done!"
