#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " Building Macroid Eco (Intel x86_64)      "
echo "=========================================="

CONFIG="${1:-release}"

swift build -c "${CONFIG}"

BINARY_PATH=".build/${CONFIG}/MacroidEco"

if [[ -f "${BINARY_PATH}" ]]; then
    echo "✓ Build succeeded: ${BINARY_PATH}"
    file "${BINARY_PATH}"
else
    echo "✗ Build artifact not found at ${BINARY_PATH}"
    exit 1
fi
