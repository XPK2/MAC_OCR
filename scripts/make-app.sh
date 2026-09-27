#!/bin/bash
# Builds a universal (Apple Silicon + Intel) MacOCR.app and packs it for other Macs:
#   build/MacOCR.app
#   dist/MacOCR-<version>.dmg   (app + Applications shortcut + installer script)
#   dist/MacOCR-<version>.zip
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source scripts/ensure-toolchain.sh

APP_NAME="MacOCR"
BUNDLE_ID="com.macocr.app"
VERSION="${VERSION:-1.0}"
MIN_MACOS="14.0"
APP_BUNDLE="build/$APP_NAME.app"

# Separate scratch paths: per-triple builds otherwise overwrite each other's products.
BINARIES=()
for ARCH in arm64 x86_64; do
    echo "==> swift build -c release ($ARCH)"
    ARGS=(-c release --triple "$ARCH-apple-macosx$MIN_MACOS" --scratch-path ".build/$ARCH")
    swift build "${ARGS[@]}"
    BINARIES+=("$(swift build "${ARGS[@]}" --show-bin-path)/$APP_NAME")
done

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
lipo -create -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "${BINARIES[@]}"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>          <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>              <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleExecutable</key>           <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>       <string>$MIN_MACOS</string>
    <key>LSApplicationCategoryType</key>    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSPrincipalClass</key>             <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>     <string>Image or PDF</string>
            <key>CFBundleTypeRole</key>     <string>Viewer</string>
            <key>LSHandlerRank</key>        <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.image</string>
                <string>com.adobe.pdf</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST
plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null

echo "==> Ad-hoc codesign"
codesign -s - --force --deep "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"

echo "==> Packaging dist/"
mkdir -p dist
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP_BUNDLE" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
cp scripts/install.sh "$STAGE/Install $APP_NAME.command"
chmod +x "$STAGE/Install $APP_NAME.command"

DMG="dist/$APP_NAME-$VERSION.dmg"
ZIP="dist/$APP_NAME-$VERSION.zip"
rm -f "$DMG" "$ZIP"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"

echo "==> Done"
lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | sed 's/^/    archs: /'
ls -lh "$DMG" "$ZIP" | awk '{print "    " $5 "  " $9}'
