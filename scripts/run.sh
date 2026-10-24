#!/usr/bin/env bash
set -euo pipefail

echo "Building Macdroid Mirror..."
swift build -c debug

echo "Launching Macdroid Mirror..."
exec .build/debug/MacdroidMirror "$@"
