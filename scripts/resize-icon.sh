#!/bin/bash
set -e

# Resize app icon from a 1024x1024 source PNG to all required iOS sizes
# Usage: ./scripts/resize-icon.sh [source.png]
# Default source: scripts/app-icon-1024.png

SOURCE="${1:-scripts/app-icon-1024.png}"
DEST="Library/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE" ]; then
    echo "Source not found: $SOURCE"
    echo "Usage: ./scripts/resize-icon.sh <1024x1024.png>"
    exit 1
fi

SIZES=(20 29 40 50 57 58 60 72 76 80 87 100 114 120 144 152 167 180 1024)

echo "Resizing $SOURCE → $DEST/"
for SIZE in "${SIZES[@]}"; do
    sips -z $SIZE $SIZE "$SOURCE" --out "$DEST/$SIZE.png" > /dev/null 2>&1
    echo "  ✓ ${SIZE}x${SIZE}"
done

echo "Done! All icon sizes generated."
