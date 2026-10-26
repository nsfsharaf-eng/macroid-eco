#!/usr/bin/env bash
set -eo pipefail

echo "=========================================="
echo " Running Macroid Eco Test Suite           "
echo "=========================================="

DEV_DIR="$(xcode-select -p 2>/dev/null || echo '/Library/Developer/CommandLineTools')"
FRAMEWORKS_DIR="${DEV_DIR}/Library/Developer/Frameworks"
USR_LIB_DIR="${DEV_DIR}/Library/Developer/usr/lib"

SWIFT_FLAGS=()
if [[ -d "${FRAMEWORKS_DIR}" ]]; then
    SWIFT_FLAGS+=(
        -Xswiftc -F -Xswiftc "${FRAMEWORKS_DIR}"
        -Xlinker -rpath -Xlinker "${FRAMEWORKS_DIR}"
    )
fi

if [[ -d "${USR_LIB_DIR}" ]]; then
    SWIFT_FLAGS+=(
        -Xlinker -rpath -Xlinker "${USR_LIB_DIR}"
    )
fi

if [[ ${#SWIFT_FLAGS[@]} -gt 0 ]]; then
    swift test "${SWIFT_FLAGS[@]}"
else
    swift test
fi

echo "✓ All test suites passed successfully."
