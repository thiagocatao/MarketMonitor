#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MarketMonitor"
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"

echo "Building $APP_NAME..."

# 1. Compile
cd "$PROJECT_DIR"
swift build -c release 2>&1

# 2. Create .app bundle
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy binary
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# 4. Copy Python script
cp "$PROJECT_DIR/Scripts/market_monitor.py" "$APP_BUNDLE/Contents/Resources/"

# 5. Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MarketMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.thiago.MarketMonitor</string>
    <key>CFBundleName</key>
    <string>MarketMonitor</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

echo ""
echo "Built: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
echo "Or install: cp -R $APP_BUNDLE /Applications/"
