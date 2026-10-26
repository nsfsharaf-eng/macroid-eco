# Macroid Eco

A native macOS application for Android screen mirroring, wireless debugging, and two-way file management, engineered specifically for Intel-based Mac computers.

![macOS Version](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Intel%20x86__64%20(Primary)%20%7C%20Apple%20Silicon-informational)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Overview

**Macroid Eco** delivers a first-class desktop environment for interacting with Android smartphones from your Mac. Built with Swift, SwiftUI, and structured concurrency, it pairs native macOS interface guidelines with the high-performance display engine of [scrcpy](https://github.com/Genymobile/scrcpy) and the Android Debug Bridge (`adb`).

Intel Macs (Core i3, i5, i7, i9) are treated as first-class release targets, with downscaling profiles and low-overhead process isolation tailored for Intel integrated and discrete GPUs.

---

## Screenshots

<!-- Add application screenshots below -->
| Mirroring Dashboard | Devices & Wireless Wi-Fi |
| :---: | :---: |
| *Dashboard with live hardware status and profiles* | *Connected devices, 1-click Wi-Fi switch & direct connect* |

| File Transfer & Storage Volumes | Interactive Conflict Resolution |
| :---: | :---: |
| *Browse Internal storage, MicroSD cards, and root* | *Safe Replace, Skip, Cancel dialog with batch apply* |

---

## Key Features

### 1. High-Performance Screen Mirroring
- **Real-Time Display**: Low-latency video streaming powered by `scrcpy`.
- **Configurable Video Profiles**: Select max resolution (720p, 1080p, 1440p, native), framerate (30 FPS, 60 FPS, unlimited), and bitrates up to 32 Mbps.
- **Audio Forwarding**: Stream audio from your Android phone directly to your Mac speakers or headphones (Android 11+).
- **Power Efficiency**: Optional "Turn Screen Off" mode keeps your physical phone display powered down while mirroring to conserve battery and keep the phone cool.
- **Keep Awake**: Prevent the phone from going to sleep while actively mirroring.

### 2. Android File Transfer & Storage Browser
- **Multi-Volume Support**: Browse and transfer to **Internal storage** (`/sdcard` / `/storage/emulated/0`), detected physical **MicroSD cards** (`/storage/XXXX-XXXX`), and the full filesystem (`/`).
- **Two-Way Transfers**: Drag and drop files from macOS Finder into the app, use the native macOS file picker, or click "Save to Mac" to download files with `NSSavePanel`.
- **Interactive Conflict Resolution**: When a destination file already exists, a native confirmation dialog prompts you to **Replace**, **Skip**, or **Cancel**, with an optional **"Apply to remaining conflicts"** toggle for batch uploads.
- **Byte-Level Verification**: Independently verifies file presence and exact byte size on the Android storage device after every transfer before reporting success.

### 3. Wireless Debugging (Cable-Free Wi-Fi)
- **One-Click Switch from USB**: Connect your phone via USB once and click **"Switch to Wireless"**. Macroid Eco automatically discovers your phone's Wi-Fi IP, restarts ADB in TCP/IP mode on port 5555, and connects wirelessly. Unplug the cable and continue wire-free!
- **Direct Wi-Fi Connect**: Enter your phone's Wi-Fi IP and port 5555 directly into the connection panel with step-by-step setup guidance.

### 4. macOS Native HIG Integration
- **Custom Application Icon**: Native high-resolution application icon (`AppIcon.icns`) with macOS squircle styling.
- **macOS Menu Bar Help (`⌘?`)**: Full integration replacing default unconfigured help alerts with native in-app guidance.
- **Dynamic Important Notice Card**: Real-time status in the sidebar for pending RSA authorizations, offline connections, or missing tools.
- **Aligned Settings & Diagnostics**: Consistent 200pt right-aligned controls, switch toggles, and one-click clipboard diagnostic reports.

---

## Compatibility

### Verified Hardware Target
- **Machine**: MacBook Pro (16-inch, Intel)
- **Processor**: 2.6 GHz 6-Core Intel Core i7
- **Memory**: 16 GB 2667 MHz DDR4
- **Graphics**: Intel UHD Graphics 630
- **macOS**: macOS 13.0 (Ventura) or later (Tested through macOS Tahoe 26.x / Sequoia)
- **Verified Mobile Devices**: Xiaomi Redmi Note 14 Pro+ 5G (HyperOS / Android 14), Google Pixel series, Samsung Galaxy series

### Platform Matrix
| Architecture | Support Tier | Minimum OS |
| :--- | :--- | :--- |
| **Intel Mac (x86_64)** | **Tier 1 (Primary / First-Class Target)** | macOS 13.0+ |
| **Apple Silicon (arm64)** | **Tier 2 (Compatible via Universal Swift Build)** | macOS 13.0+ |

---

## Prerequisites & Installation

Macroid Eco relies on standard open-source tools: `adb` and `scrcpy`.

### 1. Install Dependencies

#### Option A: Using Homebrew (Recommended)
```bash
brew install android-platform-tools scrcpy
```

#### Option B: Using MacPorts
```bash
sudo port install scrcpy android-platform-tools
```

*Note: If you have ADB installed through Android Studio, Macroid Eco automatically detects it under `~/Library/Android/sdk/platform-tools/adb` or allows you to specify a custom path in Settings.*

### 2. Enable Android USB Debugging
1. On your phone, open **Settings > About Phone**.
2. Tap **Build Number** 7 times until Developer options are enabled.
3. Open **Settings > System > Developer Options** (or **Additional Settings > Developer Options** on Xiaomi / HyperOS).
4. Turn ON **USB Debugging**.
5. Connect your phone to your Mac using a quality USB data cable.
6. Unlock your phone screen, check **Always allow from this computer**, and tap **Allow** on the RSA authorization prompt.

---

## Building from Source

### 1. Clone the Repository
```bash
git clone https://github.com/nsfsharaf-eng/macroid-eco.git
cd macroid-eco
```

### 2. Run the Automated Test Suite
```bash
./scripts/test.sh
```
*Executes all 49 unit tests across 8 suites covering device discovery, argument parsing, file transfers, conflict resolution, and session state machines.*

### 3. Build the Release Binary
```bash
./scripts/build.sh release
```
*Compiles the optimized Intel `x86_64` Mach-O binary to `.build/release/MacroidEco`.*

### 4. Package the Native Application Bundle
```bash
./scripts/package_app.sh
```
*Creates a standalone, double-clickable macOS application bundle at `.build/release/Macroid Eco.app` complete with `Info.plist`, icons, and executable.*

### 5. Launch the Application
```bash
open ".build/release/Macroid Eco.app"
```

---

## File Transfer & Conflict Handling

Macroid Eco includes a safe, verified Android file transfer engine:

1. **Browsing Storage**: Navigate folders in the file list or click any breadcrumb segment in the header. Switch storage volumes using the dropdown in the top-right corner.
2. **Uploading to Phone**:
   - Drag and drop files from macOS Finder directly into the drop zone.
   - Or click **Send Files to Phone** and select files via the native file open panel.
3. **Duplicate Filename Handling**:
   - Before writing, Macroid Eco checks the destination path on the Android device.
   - If a duplicate exists, a native modal dialog appears:
     - **Replace**: Overwrites the existing remote file.
     - **Skip**: Leaves the existing remote file untouched.
     - **Cancel**: Aborts the operation immediately.
     - **Apply to remaining conflicts**: Batch applies your decision to all remaining conflicting files in the transfer batch.
4. **Hardware Verification**:
   - After ADB finishes pushing the file, Macroid Eco independently queries the remote filesystem with `stat` to verify the file exists and that its remote byte count matches the source file exactly.
5. **Downloading to Mac**: Click **Save to Mac** next to any remote file to select a local folder with `NSSavePanel`.

---

## Wireless Debugging Instructions

### Method 1: One-Click Switch from USB (Recommended)
1. Plug your phone into your Mac via USB data cable.
2. In Macroid Eco, go to **Connected Devices**.
3. Under the **Wireless Debugging** card, click **Switch to Wireless**.
4. Macroid Eco enables TCP/IP mode on port 5555 and establishes the Wi-Fi connection.
5. Unplug the USB cable! Mirroring and file transfers will continue wirelessly.

### Method 2: Direct Wi-Fi Connect (Port 5555)
1. Ensure both your phone and Mac are connected to the same Wi-Fi network.
2. On your phone, find your IP address in **Settings > About Phone > Status > IP address** (e.g., `192.168.1.100`).
3. In **Connected Devices**, enter the phone's IP address and Port `5555`, then click **Connect Wi-Fi**.

---

## Privacy & Security

- **100% Offline & Local**: Macroid Eco contains zero analytics, zero cloud services, and zero telemetry. All video streaming and file transfers travel strictly over your local USB cable or local private Wi-Fi network.
- **Standard Unprivileged Interfaces**: Operates entirely within standard user-space ADB permissions. No root access is required.
- **Safe Process Invocation**: All commands (`adb`, `scrcpy`) are passed as discrete argument arrays directly to `Foundation.Process`. No shell string interpolation (`/bin/sh -c`) is used, preventing command injection vulnerabilities.
- **Clean Signal Lifecycle**: Mirroring processes terminate cleanly via `SIGTERM` / `SIGKILL` on session stop or app exit, leaving no orphaned background processes.

---

## Troubleshooting

- **Device Shows "Unauthorized"**: Unlock your phone screen. An RSA prompt will appear. Check *Always allow from this computer* and tap *Allow*.
- **Device Shows "Offline"**: Reconnect your USB cable or click **Restart ADB** in the Connected Devices screen.
- **Wi-Fi Connection Fails**: Ensure both your Mac and phone are on the same local Wi-Fi subnet. Guest or public networks with "AP Client Isolation" block device-to-device traffic. Connect your phone to your Mac's Wi-Fi Personal Hotspot for a direct connection.
- **scrcpy Not Found**: Install via `brew install scrcpy` or provide the path in **Settings > Custom scrcpy Path**.
- **Help Menu**: Press `⌘?` or click **Help > Macroid Eco Help** in the macOS menu bar to open the in-app help guide.

---

## Project Status & Roadmap

- [x] Native macOS SwiftUI interface with Intel x86_64 optimization
- [x] External dependency discovery (`adb`, `scrcpy`)
- [x] USB device discovery and mirroring controls
- [x] Real-time session state synchronization
- [x] Two-way Android file transfer engine with byte verification
- [x] Multi-volume storage support (Internal storage, MicroSD cards, Root)
- [x] Interactive duplicate file conflict resolution (Replace, Skip, Cancel, Apply to all)
- [x] One-click USB to Wireless TCP/IP switching
- [x] Direct Wi-Fi connection by IP and port 5555
- [x] Custom application icon and macOS menu bar help routing
- [ ] Direct embedded Metal viewport (in-window rendering alternative to standalone scrcpy window)
- [ ] Drag-and-drop APK installation directly into the file transfer module

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

Third-party open-source components (`scrcpy`, `adb`, `SDL2`) retain their respective Apache 2.0 and zlib licenses as documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
