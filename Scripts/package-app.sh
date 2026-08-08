#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
PRODUCT_NAME="ExplorerPP"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$PRODUCT_NAME.app"
DMG_PATH="$DIST_DIR/$PRODUCT_NAME.dmg"
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
DMG_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$(dirname "$ICONSET_DIR")" "$DMG_ROOT"
}
trap cleanup EXIT

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_PATH" "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$ICONSET_DIR"

cp "$BIN_DIR/$PRODUCT_NAME" "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"

create_icon() {
    local size="$1"
    local output="$2"
    sips -z "$size" "$size" "$ROOT_DIR/Assets/AppIcon.png" --out "$ICONSET_DIR/$output" >/dev/null
}

create_icon 16 icon_16x16.png
create_icon 32 icon_16x16@2x.png
create_icon 32 icon_32x32.png
create_icon 64 icon_32x32@2x.png
create_icon 128 icon_128x128.png
create_icon 256 icon_128x128@2x.png
create_icon 256 icon_256x256.png
create_icon 512 icon_256x256@2x.png
create_icon 512 icon_512x512.png
create_icon 1024 icon_512x512@2x.png
iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign "$SIGN_IDENTITY" --timestamp=none "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$DMG_ROOT"
ditto "$APP_PATH" "$DMG_ROOT/$PRODUCT_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$DMG_ROOT" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

printf 'Created %s\n' "$APP_PATH"
printf 'Created %s\n' "$DMG_PATH"
