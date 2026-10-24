# Contributing to Macdroid Mirror

Thank you for your interest in contributing to Macdroid Mirror!

## Architecture Overview

- **MacdroidMirrorCore**: Shared Swift library containing domain models (`Device`, `SessionState`, `MirroringConfig`, `DependencyStatus`), services (`DeviceService`, `MirroringSessionManager`, `DependencyService`, `PreferencesService`), and `AppViewModel`.
- **MacdroidMirror**: Native macOS SwiftUI application executable.
- **MacdroidMirrorTests**: Comprehensive XCTest unit and integration test suite.

## Development Requirements

- macOS 13.0 or later (Tested on macOS Tahoe / Sonoma / Ventura)
- Intel x86_64 or Apple Silicon Mac (Universal target)
- Xcode 15+ or Swift Command Line Tools 5.9+
- Optional: `adb` (Android platform-tools) and `scrcpy` installed via Homebrew or MacPorts

## Building and Running

### Command Line
```bash
# Build the application
swift build

# Run unit tests
swift test
```

### Xcode
Open `Package.swift` in Xcode or open the generated project:
```bash
open Package.swift
```

## Pull Request Guidelines

1. **Maintain Intel x86_64 Compatibility**:
   Macdroid Mirror treats Intel Macs as first-class citizens. Avoid Apple-Silicon-only APIs without appropriate availability guards.
2. **Automated Testing**:
   Add unit tests in `Tests/MacdroidMirrorTests/` for any new parsing logic, arguments, or state transitions. Ensure `swift test` passes cleanly.
3. **No Shell Injections**:
   Never use shell expansion or concatenated shell strings when invoking subprocesses. Always use discrete argument arrays with `ProcessRunning`.
4. **Code Style**:
   Follow standard Swift API Design Guidelines. Keep SwiftUI views modular and maintain separation between presentation, state, and services.
