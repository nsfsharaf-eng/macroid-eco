# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-24

### Added
- Native macOS SwiftUI dashboard with deep navy (`#0A0E18`) and graphite (`#141A26`) foundations and restrained electric blue accents.
- Modular architecture with `MacdroidMirrorCore`, `MacdroidMirror` executable, and `MacdroidMirrorTests`.
- External dependency detection for Android Debug Bridge (`adb`) and `scrcpy` across standard paths (`/usr/local/bin`, `/opt/homebrew/bin`, `/opt/local/bin`, Android SDK).
- Android USB and TCP/IP device discovery engine with parsing for `adb devices -l`.
- Support for device states: `authorized`, `unauthorized`, `offline`, `authorizing`, `recovery`, `bootloader`.
- `MirroringSessionManager` providing managed `Process` execution, active state tracking, clean shutdown (`SIGTERM` -> `SIGKILL`), and disconnection detection.
- Clean process termination on `NSApplication.willTerminateNotification` to prevent orphaned background windows.
- Video and behavior configuration (Framerate capping, max resolution, bitrate, stay-awake, screen power savings, audio forwarding).
- Diagnostics view with system architecture audit, memory verification, and clipboard diagnostic reporting.
- Interactive troubleshooting guide with step-by-step developer options setup and scrcpy keyboard shortcuts.
- Comprehensive XCTest suite covering device parsing, configuration sanitization, dependency checks, and session states.
- GitHub Actions CI workflow for building and testing on macOS.
