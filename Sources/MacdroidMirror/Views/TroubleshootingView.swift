import SwiftUI
import MacdroidMirrorCore

public struct TroubleshootingView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection & Troubleshooting Guide")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Comprehensive instructions for USB debugging, Wireless connection, Direct Connect, and mirroring shortcuts.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Section 1: USB Debugging Guide
                usbDebuggingGuide

                // Section 2: Wireless & Direct Connect Guide (Matches USB Guide)
                wirelessDirectConnectGuide

                // Section 3: Wireless Troubleshooting & Protocol Fault Fixes
                wirelessTroubleshootingGuide

                // Section 4: Authorization & Offline Fixes
                authorizationFixes

                // Section 5: Hardware & USB Cable Tips
                hardwareTips

                // Section 6: scrcpy Keyboard & Mouse Shortcuts
                shortcutsCheatSheet
            }
            .padding(24)
        }
    }

    // MARK: - Sections

    private var usbDebuggingGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("1. Enable Android USB Debugging", systemImage: "gearshape.2")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                stepItem(number: "1", text: "Open Settings on your Android phone and scroll down to About Phone.")
                stepItem(number: "2", text: "Locate Build Number (or OS Version on HyperOS / MIUI) and tap it rapidly 7 times until you see 'You are now a developer!'.")
                stepItem(number: "3", text: "Return to Settings > System (or Additional Settings) > Developer Options.")
                stepItem(number: "4", text: "Toggle USB Debugging to the ON position.")
                stepItem(number: "5", text: "Connect your phone to your Mac using a USB-C data cable and unlock your screen to accept the RSA debugging prompt.")
            }
        }
        .cardStyled()
    }

    private var wirelessDirectConnectGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("2. Wireless Debugging & Direct Connect Guide", systemImage: "wifi")
                .font(.headline)

            Text("Two reliable ways to mirror and transfer files wirelessly over your local Wi-Fi network:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                // Method A
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Method A: One-Click Switch from USB (Easiest & Most Reliable)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.electricBlue)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        stepItem(number: "1", text: "Connect your phone to your Mac via USB cable once.")
                        stepItem(number: "2", text: "In Macroid Eco, go to Connected Devices and click 'Switch to Wireless'.")
                        stepItem(number: "3", text: "Macroid Eco activates TCP mode (port 5555) and connects automatically.")
                        stepItem(number: "4", text: "Unplug the USB cable! Mirroring and file transfer will continue wire-free.")
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(AppTheme.elevatedSurface.opacity(0.45))
                )

                // Method B
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Method B: Direct Wi-Fi Connect (Port 5555)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.electricBlue)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        stepItem(number: "1", text: "Ensure your phone and Mac are connected to the same Wi-Fi network.")
                        stepItem(number: "2", text: "Find your phone's Wi-Fi IP in Settings > About Phone > Status > IP address (e.g. 192.168.1.100).")
                        stepItem(number: "3", text: "In Connected Devices, enter the phone IP and Port 5555, then click 'Connect Wi-Fi'.")
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(AppTheme.elevatedSurface.opacity(0.45))
                )
            }
        }
        .cardStyled()
    }

    private var wirelessTroubleshootingGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("3. Troubleshooting Wireless Connection Errors", systemImage: "exclamationmark.triangle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                stepItem(
                    number: "A",
                    text: "Port 5555 Mode: Ensure TCP/IP mode is activated by plugging into USB once and clicking 'Switch to Wireless'. When prompted on your phone, accept the RSA authorization dialog."
                )
                stepItem(
                    number: "B",
                    text: "Wi-Fi Network Isolation: Public or guest Wi-Fi networks often block device-to-device communication (AP Client Isolation). Both devices must be on a private home or office Wi-Fi, or connect your phone to your Mac's Wi-Fi Personal Hotspot."
                )
                stepItem(
                    number: "C",
                    text: "HyperOS / MIUI / Samsung Auto-Off: Android frequently turns Wireless Debugging off when Wi-Fi reconnects. If connection drops, reopen Developer options and re-enable Wireless debugging."
                )
            }
        }
        .cardStyled()
    }

    private var authorizationFixes: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("4. Fixing 'Unauthorized' or 'Offline' States", systemImage: "lock.shield")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                stepItem(
                    number: "A",
                    text: "Accept RSA Prompt: Unlock your phone screen. An RSA key authorization dialog should pop up. Select 'Always allow from this computer' and tap 'Allow'."
                )
                stepItem(
                    number: "B",
                    text: "Revoke Stale Authorizations: In Developer Options, scroll to 'Revoke USB debugging authorizations', confirm, unplug the USB cable, and reconnect."
                )
                stepItem(
                    number: "C",
                    text: "Restart ADB Daemon: In Macroid Eco, click 'Restart ADB' in Devices, or open Terminal and run: 'adb kill-server && adb start-server'."
                )
            }
        }
        .cardStyled()
    }

    private var hardwareTips: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("5. USB Cables & Mac Ports", systemImage: "cable.connector")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                bulletItem(text: "Use a genuine high-speed data transfer cable. Many thin cables are power-only and cannot carry USB debugging signals.")
                bulletItem(text: "Connect directly to your MacBook Pro USB-C ports whenever possible. Inexpensive unpowered hubs can drop connection packets during high-bandwidth video mirroring.")
                bulletItem(text: "Ensure USB mode on the phone is set to 'File Transfer (MTP)' rather than 'Charging only' when connected.")
            }
        }
        .cardStyled()
    }

    private var shortcutsCheatSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("6. Mirroring Interaction & Shortcuts", systemImage: "keyboard")
                .font(.headline)

            Text("While the scrcpy mirroring window is focused, use these standard macOS shortcuts:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                shortcutRow(keys: "Right Click / Cmd + B", action: "Back Button")
                Divider()
                shortcutRow(keys: "Middle Click / Cmd + H", action: "Home Screen")
                Divider()
                shortcutRow(keys: "Cmd + S", action: "Take Screenshot")
                Divider()
                shortcutRow(keys: "Cmd + F", action: "Toggle Fullscreen")
                Divider()
                shortcutRow(keys: "Cmd + O", action: "Turn Physical Screen Off (Keep Mirroring)")
                Divider()
                shortcutRow(keys: "Cmd + P", action: "Power Button (Wake/Sleep)")
                Divider()
                shortcutRow(keys: "Cmd + N", action: "Expand Notification Shade")
                Divider()
                shortcutRow(keys: "Drag & Drop .apk", action: "Install App directly")
                Divider()
                shortcutRow(keys: "Drag & Drop files", action: "Push files to selected Android storage folder")
            }
        }
        .cardStyled()
    }

    // MARK: - Helper Views

    private func stepItem(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppTheme.electricBlue.opacity(0.18)))
                .foregroundColor(AppTheme.electricBlue)
                .padding(.top, 1)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletItem(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(AppTheme.electricBlue)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortcutRow(keys: String, action: String) -> some View {
        HStack {
            Text(action)
                .font(.callout)

            Spacer()

            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
    }
}
