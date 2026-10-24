import SwiftUI

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
                    Text("Step-by-step instructions for Android USB debugging, authorization, and scrcpy controls.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Section 1: Developer Options & USB Debugging
                usbDebuggingGuide

                // Section 2: Authorization & Offline Fixes
                authorizationFixes

                // Section 3: Hardware & USB Cable Tips
                hardwareTips

                // Section 4: scrcpy Keyboard & Mouse Shortcuts
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
                stepItem(number: "2", text: "Locate Build Number (often inside Software Information) and tap it rapidly 7 times until you see 'You are now a developer!'.")
                stepItem(number: "3", text: "Return to Settings > System (or Additional Settings) > Developer Options.")
                stepItem(number: "4", text: "Toggle USB Debugging to the ON position.")
            }
        }
        .cardStyled()
    }

    private var authorizationFixes: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("2. Fixing 'Unauthorized' or 'Offline' States", systemImage: "lock.shield")
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
                    text: "Restart ADB Daemon: Open Terminal and run: 'adb kill-server && adb start-server'."
                )
            }
        }
        .cardStyled()
    }

    private var hardwareTips: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("3. USB Cables & Mac Ports", systemImage: "cable.connector")
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
            Label("4. Mirroring Interaction & Shortcuts", systemImage: "keyboard")
                .font(.headline)

            Text("While the scrcpy mirroring window is focused, use these standard macOS shortcuts:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                shortcutRow(keys: "Right Click / Cmd + B", action: "Back Button")
                shortcutRow(keys: "Middle Click / Cmd + H", action: "Home Screen")
                shortcutRow(keys: "Cmd + S", action: "Take Screenshot")
                shortcutRow(keys: "Cmd + F", action: "Toggle Fullscreen")
                shortcutRow(keys: "Cmd + O", action: "Turn Physical Screen Off (Keep Mirroring)")
                shortcutRow(keys: "Cmd + P", action: "Power Button (Wake/Sleep)")
                shortcutRow(keys: "Cmd + N", action: "Expand Notification Shade")
                shortcutRow(keys: "Drag & Drop .apk", action: "Install App directly")
                shortcutRow(keys: "Drag & Drop files", action: "Push files to /sdcard/Download/")
            }
        }
        .cardStyled()
    }

    // MARK: - Helper Views

    private func stepItem(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppTheme.electricBlue.opacity(0.18)))
                .foregroundColor(AppTheme.electricBlue)

            Text(text)
                .font(.callout)
        }
    }

    private func bulletItem(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(AppTheme.electricBlue)
                .fontWeight(.bold)
            Text(text)
                .font(.callout)
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
