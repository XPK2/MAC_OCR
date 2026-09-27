#!/bin/bash
# Sourced by build scripts: installs Xcode Command Line Tools (Swift toolchain) if missing.
# Only needed to BUILD from source — the packaged MacOCR.app needs nothing extra
# (Vision, PDFKit and the Swift runtime ship with macOS 14+).

if ! xcrun --find swift >/dev/null 2>&1; then
    echo "==> Chưa có Swift toolchain → đang tải Xcode Command Line Tools…"
    echo "    Bấm 'Install' trong hộp thoại vừa hiện ra, script sẽ tự chạy tiếp khi cài xong."
    xcode-select --install >/dev/null 2>&1 || true
    until xcrun --find swift >/dev/null 2>&1; do sleep 10; done
    echo "==> Đã cài Command Line Tools."
fi

# CLT ships Swift Testing under a path SwiftPM doesn't search on its own.
CLT_DIR="$(xcode-select -p)"
TESTING_FLAGS=()
if [ -d "$CLT_DIR/Library/Developer/Frameworks/Testing.framework" ]; then
    FW="$CLT_DIR/Library/Developer/Frameworks"
    TESTING_FLAGS=(
        -Xswiftc -F -Xswiftc "$FW"
        -Xswiftc -plugin-path -Xswiftc "$CLT_DIR/usr/lib/swift/host/plugins/testing"
        -Xlinker -F -Xlinker "$FW"
        -Xlinker -rpath -Xlinker "$FW"
    )
fi
