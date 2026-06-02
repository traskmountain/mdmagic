#!/bin/bash
# Build MDMagic and package it into a double-clickable .app bundle.
set -e
cd "$(dirname "$0")"

# Pass --universal to build a fat arm64 + x86_64 binary (used for releases).
if [ "$1" = "--universal" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN=".build/apple/Products/Release/MDMagic"
else
    swift build -c release
    BIN=".build/release/MDMagic"
fi

APP="MDMagic.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MDMagic"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MDMagic</string>
    <key>CFBundleDisplayName</key><string>MDMagic</string>
    <key>CFBundleIdentifier</key><string>com.local.mdmagic</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>MDMagic</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Markdown Document</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.plain-text</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array><string>md</string><string>markdown</string><string>mdown</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# ad-hoc sign so Gatekeeper lets it run locally
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Built $APP"
