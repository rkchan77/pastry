#!/bin/bash
# Builds Pastry.app next to this script. Needs Xcode or the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="Pastry.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pastry "$APP/Contents/MacOS/Pastry"
mkdir -p "$APP/Contents/Resources"

# Menu bar / empty-state pancake glyph.
cp Resources/PancakeTemplate.png "$APP/Contents/Resources/" 2>/dev/null || true

# App icon: turn Resources/AppIcon.png (1024×1024, transparent corners) into AppIcon.icns.
mkdir -p "$APP/Contents/Resources"
if [ -f Resources/AppIcon.png ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z $double $double Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
else
    echo "Note: Resources/AppIcon.png not found — building without an icon."
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Pastry</string>
    <key>CFBundleDisplayName</key><string>Pastry</string>
    <key>CFBundleIdentifier</key><string>com.ryanchan.pastry</string>
    <key>CFBundleExecutable</key><string>Pastry</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP — move it to /Applications and open it."
