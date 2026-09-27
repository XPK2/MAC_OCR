#!/bin/bash
# Installs MacOCR.app on this Mac.
# - Shipped inside the DMG as "Install MacOCR.command": copies the bundled app.
# - Run from a source checkout (scripts/install.sh): builds first, auto-installing
#   Xcode Command Line Tools if missing.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="MacOCR"

MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt 14 ]; then
    echo "Lỗi: $APP_NAME cần macOS 14 trở lên (máy này: $(sw_vers -productVersion))." >&2
    exit 1
fi

if [ -d "$HERE/$APP_NAME.app" ]; then
    SRC="$HERE/$APP_NAME.app"
elif [ -f "$HERE/../Package.swift" ]; then
    echo "==> Không có bản build sẵn → build từ source"
    "$HERE/make-app.sh"
    SRC="$HERE/../build/$APP_NAME.app"
else
    echo "Lỗi: không tìm thấy $APP_NAME.app cạnh script này." >&2
    exit 1
fi

if [ -n "${INSTALL_DIR:-}" ]; then DEST_DIR="$INSTALL_DIR"
elif [ -w /Applications ]; then DEST_DIR=/Applications
else DEST_DIR="$HOME/Applications"; fi
mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/$APP_NAME.app"

osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
rm -rf "$DEST"
ditto "$SRC" "$DEST"
# App is ad-hoc signed (not notarized): drop the download quarantine flag so Gatekeeper doesn't block it.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Đã cài: $DEST"
open "$DEST"
