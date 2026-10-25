#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " Packaging Macdroid Mirror Application    "
echo "=========================================="

./scripts/build.sh release

APP_DIR=".build/release/MacdroidMirror.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy executable
cp ".build/release/MacdroidMirror" "${MACOS_DIR}/MacdroidMirror"
chmod +x "${MACOS_DIR}/MacdroidMirror"

# Copy Info.plist
if [[ -f "Resources/Info.plist" ]]; then
    cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
    plutil -lint "${CONTENTS_DIR}/Info.plist"
fi

echo "✓ Successfully assembled native macOS application bundle:"
echo "  ${APP_DIR}"
ls -la "${MACOS_DIR}"
