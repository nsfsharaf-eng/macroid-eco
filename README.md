# Macdroid Mirror

A polished native macOS application for mirroring and interacting with Android devices from Intel-based Mac computers.

![macOS Version](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Intel%20x86__64%20(Primary)%20%7C%20Apple%20Silicon-informational)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Overview

**Macdroid Mirror** delivers a first-class macOS desktop experience for discovering, controlling, and mirroring Android smartphones. Built with Swift, SwiftUI, and structured concurrency, it combines native macOS system design with the high-performance display engine of [scrcpy](https://github.com/Genymobile/scrcpy) and Android Debug Bridge (`adb`).

Intel Macs (Core i3, i5, i7, i9) are treated as first-class release targets, with optimized framerates, low-overhead process isolation, and downscaling profiles tailored for Intel integrated and discrete GPUs.

---

## Key Features

- **Native macOS Dashboard**: Designed with deep navy (`#0A0E18`) and graphite foundations, subtle borders, and electric blue accents.
- **Automated Dependency Detection**: Automatic discovery and version validation for ADB and scrcpy across standard Homebrew, MacPorts, and Android SDK directories.
- **Real-Time Device Discovery**: Live parsing of `adb devices -l` output, clearly distinguishing authorized, unauthorized, offline, recovery, and bootloader states.
- **Process Lifecycle Management**: Safe invocation of external tools via `Foundation.Process` with discrete argument arrays (no shell concatenation), active PID monitoring, and clean signal termination (`SIGTERM` / `SIGKILL`).
- **Performance & Display Profiles**: Fine-tune maximum framerate (30 / 60 / Native FPS), downscale resolution, customize bitrate, and toggle display power-saving (turn physical screen off).
- **Audio Forwarding**: Stream phone audio directly through Mac speakers (Android 11+).
- **Diagnostics & Troubleshooting**: Built-in environment verification, candidate search logging, one-click diagnostic report copying, and an interactive USB debugging guide.

---

## Hardware & System Compatibility

### Verified Development Target
- **Model**: 16-inch MacBook Pro
- **Processor**: 2.6 GHz 6-core Intel Core i7
- **Memory**: 16 GB 2667 MHz DDR4
- **Graphics**: Intel UHD Graphics 630 (1536 MB)
- **Host OS**: macOS Tahoe 26.7.1 (Build 25G241)

### Compatibility Matrix
| Platform / Architecture | Support Tier | Minimum OS |
| :--- | :--- | :--- |
| **Intel Mac (x86_64)** | **Tier 1 (First-Class / Primary)** | macOS 13.0 (Ventura) |
| **Apple Silicon (arm64)** | **Tier 2 (Universal Target)** | macOS 13.0 (Ventura) |

---

## Prerequisites & Installation

Macdroid Mirror relies on two battle-tested open-source utilities: `adb` and `scrcpy`.

### 1. Install Dependencies

#### Using Homebrew (Recommended):
```bash
brew install android-platform-tools scrcpy
```

#### Using MacPorts:
```bash
sudo port install scrcpy
```

### 2. Enable Android USB Debugging
1. On your Android phone, navigate to **Settings > About Phone**.
2. Tap **Build Number** 7 times until Developer Mode is unlocked.
3. Go to **Settings > System > Developer Options**.
4. Enable **USB Debugging**.
5. Connect your phone to your Mac using a genuine USB data cable.
6. Unlock your phone screen, check **Always allow from this computer**, and tap **Allow** on the RSA key prompt.

---

## Building from Source

### Using Swift Package Manager (Terminal)

```bash
# Clone the repository
git clone https://github.com/macdroid-mirror/macdroid-mirror.git
cd macdroid-mirror

# Build release binary
swift build -c release

# Run the test suite
swift test
```

### Using Xcode
Open the repository root in Xcode:
```bash
open Package.swift
```
Select the **MacdroidMirror** scheme and click **Run** (`⌘R`).

---

## Project Structure

```
MacdroidMirror/
├── Package.swift                     # Swift Package definition
├── Sources/
│   ├── MacdroidMirrorCore/           # Core library
│   │   ├── Models/                   # Device, SessionState, Config, DependencyStatus
│   │   ├── Services/                 # DeviceService, MirroringSessionManager, DependencyService, Preferences
│   │   └── ViewModels/               # AppViewModel
│   └── MacdroidMirror/               # macOS Native Application
│       ├── App/                      # MacdroidMirrorApp entry point
│       └── Views/                    # SwiftUI Views (Overview, Devices, Settings, Diagnostics, Troubleshooting)
├── Tests/
│   └── MacdroidMirrorTests/          # XCTest suites (Device parsing, Config, State machines)
├── .github/
│   └── workflows/                    # GitHub Actions CI
├── README.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
├── THIRD_PARTY_NOTICES.md
└── CHANGELOG.md
```

---

## Security & Privacy

- **No Bypass of Android Security**: Full enforcement of the Android RSA authorization handshake.
- **No Root Required**: Operates completely unprivileged.
- **Zero Telemetry**: No network transmission, analytics, or remote logging. All communication remains strictly local via USB.
- **Safe Subprocesses**: Discrete argument arrays are passed to `Foundation.Process`, eliminating shell script string interpolation and command injection risks.

See [SECURITY.md](SECURITY.md) for full details.

---

## Known Limitations & Roadmap

- **Milestone 0.1**: Initial release utilizes scrcpy's native standalone window. Keyboard and mouse controls pass directly through scrcpy.
- **Milestone 0.2**: Wireless pairing (TCP/IP adb pairing) workflow and auto-reconnect.
- **Milestone 0.3**: Direct embedded video frame rendering using Metal / AVFoundation.

---

## License & Third-Party Notices

Macdroid Mirror is open source under the [MIT License](LICENSE).
Third-party component notices for `scrcpy` (Apache 2.0) and `adb` (Apache 2.0) are detailed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
