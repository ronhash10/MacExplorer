#!/bin/bash
set -e

VERSION="${1:-1.0.0}"
DMG_FILE="build/MacExplorer-${VERSION}.dmg"

if [ ! -f "$DMG_FILE" ]; then
    echo "DMG not found. Building first..."
    ./build-dmg.sh "$VERSION"
fi

# Compute SHA256 for Homebrew cask
SHA256=$(shasum -a 256 "$DMG_FILE" | awk '{print $1}')

echo "=== Release v${VERSION} ==="
echo ""

# Update cask formula with correct sha256
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Formula/macexplorer.rb
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Formula/macexplorer.rb
echo "Updated Formula/macexplorer.rb with sha256: ${SHA256}"
echo ""

# Create GitHub release
echo "Creating GitHub release..."
gh release create "v${VERSION}" "$DMG_FILE" \
    --title "MacExplorer v${VERSION}" \
    --notes "## MacExplorer v${VERSION}

### Install

**DMG:** Download \`MacExplorer-${VERSION}.dmg\` below, open it, and drag to Applications.

**Homebrew:**
\`\`\`bash
brew tap ronhash10/macexplorer https://github.com/ronhash10/MacExplorer
brew install --cask macexplorer
\`\`\`

### Requirements
- macOS 14 (Sonoma) or later
- Grant Full Disk Access for best experience
"

echo ""
echo "=== Done! ==="
echo ""
echo "Users can now install with:"
echo "  brew tap ronhash10/macexplorer https://github.com/ronhash10/MacExplorer"
echo "  brew install --cask macexplorer"
echo ""
echo "Don't forget to commit the updated Formula/macexplorer.rb!"
