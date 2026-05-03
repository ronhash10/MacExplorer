#!/bin/bash
set -e

APP_DIR="/Applications/MacExplorer.app"
BUNDLE_ID="com.macexplorer.app"
FINDER_ID="com.apple.finder"

case "${1:-}" in
    set)
        echo "Setting MacExplorer as default folder handler..."
        /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR"
        duti -s "$BUNDLE_ID" public.folder all
        echo "Done! 'open <folder>' will now use MacExplorer."
        echo "You may need to log out and back in for full effect."
        ;;
    unset)
        echo "Restoring Finder as default folder handler..."
        duti -s "$FINDER_ID" public.folder all
        echo "Done! Finder is the default again."
        ;;
    status)
        echo "Current default folder handler:"
        duti -d public.folder 2>/dev/null || echo "  (could not determine)"
        ;;
    *)
        echo "Usage: $0 {set|unset|status}"
        echo ""
        echo "  set    - Make MacExplorer the default for 'open <folder>'"
        echo "  unset  - Restore Finder as default"
        echo "  status - Show current default handler"
        exit 1
        ;;
esac
