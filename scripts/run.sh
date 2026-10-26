#!/usr/bin/env bash
set -euo pipefail

echo "Building Macroid Eco..."
swift build -c debug

echo "Launching Macroid Eco..."
exec .build/debug/MacroidEco "$@"
