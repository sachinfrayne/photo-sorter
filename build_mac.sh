#!/bin/bash
# Builds PhotoSorter.app — run this on a Mac (needs the Xcode Command Line
# Tools: `xcode-select --install` if `swift build` isn't found).
# Output: dist/PhotoSorter.app and dist/PhotoSorter.dmg
set -e
cd "$(dirname "$0")"

APP_NAME="PhotoSorter"
BUNDLE_ID="com.sachinfrayne.photosorter"
VERSION="1.0.0"
BUILD_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME (release)..."
swift build -c release

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp icon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.photography</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Signing (ad-hoc — no paid Apple Developer account needed)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Creating DMG..."
rm -rf "$BUILD_DIR/dmg-staging"
mkdir -p "$BUILD_DIR/dmg-staging"
cp -R "$APP_BUNDLE" "$BUILD_DIR/dmg-staging/"
cp "packaging/FIRST TIME ON MAC.txt" "$BUILD_DIR/dmg-staging/"
ln -s /Applications "$BUILD_DIR/dmg-staging/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$BUILD_DIR/dmg-staging" -ov -format UDZO "$BUILD_DIR/$APP_NAME.dmg"
rm -rf "$BUILD_DIR/dmg-staging"

echo ""
echo "Done: $BUILD_DIR/$APP_NAME.dmg"
echo "($BUILD_DIR/$APP_NAME.app also built directly, if you just want to drag that into a photos folder yourself.)"
