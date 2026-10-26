import SwiftUI
import MacdroidMirrorCore

public struct HelpView: View {
    @ObservedObject var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Macroid Eco Help & Guide")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Comprehensive guide for screen mirroring, wireless debugging, file transfers, and controls.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.selectedSection = .troubleshooting
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Troubleshooting")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                // Quick Start Card
                quickStartCard

                // Wireless Debugging Guide
                wirelessGuideCard

                // File Transfer Guide
                fileTransferGuideCard

                // Mirroring Controls & Settings
                mirroringFeaturesCard

                // Frequently Asked Questions (FAQ)
                faqCard

                // Privacy & Local Operation Note
                privacyCard
            }
            .padding(24)
        }
    }

    // MARK: - Subviews

    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Quick Start: USB Mirroring in 30 Seconds", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(AppTheme.electricBlue)

            VStack(alignment: .leading, spacing: 10) {
                helpStep(number: "1", title: "Enable USB Debugging on Phone", detail: "Go to Settings > About Phone, tap 'Build Number' 7 times, then go to Developer Options and turn ON 'USB Debugging'.")
                helpStep(number: "2", title: "Connect via USB-C Cable", detail: "Connect your phone to your Mac using a high-quality data cable. Unlock your phone screen and tap 'Always allow' on the RSA prompt.")
                helpStep(number: "3", title: "Click 'Mirror Device'", detail: "Select your device under Connected Devices and click 'Mirror Device'. Your phone screen will appear in an interactive native window.")
            }
        }
        .cardStyled()
    }

    private var wirelessGuideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Wireless Mirroring (Cable-Free Wi-Fi)", systemImage: "wifi")
                .font(.headline)

            Text("You can mirror and transfer files completely without cables using your local Wi-Fi network.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Method 1: One-Click Switch from USB (Recommended)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.electricBlue)
                    Text("Plug your phone in once, click 'Switch to Wireless' in Devices, then unplug the cable. It connects over Wi-Fi port 5555 instantly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Method 2: Direct Wi-Fi Connect (Port 5555)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.electricBlue)
                    Text("If wireless debugging or TCP/IP mode is active on your phone, find your IP in Settings > About Phone > Status, enter it with port 5555, and click 'Connect Wi-Fi'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .cardStyled()
    }

    private var fileTransferGuideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("File Transfer & Storage Guide", systemImage: "arrow.up.arrow.down.square")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                helpStep(number: "1", title: "Pushing Files (Mac to Phone)", detail: "Drag and drop any files from Finder into the drop zone, or click 'Send Files to Phone'. Files are safely uploaded to the active Android directory.")
                helpStep(number: "2", title: "Conflict Resolution Dialog", detail: "If a file with the same name already exists on the phone, a confirmation dialog appears with Replace, Skip, or Cancel options, with an optional 'Apply to all' batch toggle.")
                helpStep(number: "3", title: "Saving Files (Phone to Mac)", detail: "Browse your phone folders in the file list and click 'Save to Mac' next to any file. A native macOS save panel will let you choose where to save it.")
                helpStep(number: "4", title: "Internal Storage & SD Cards", detail: "Use the Storage selector to switch between 'Internal storage', detected physical SD cards, and 'Entire Device (/)'.")
            }
        }
        .cardStyled()
    }

    private var mirroringFeaturesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Mirroring Controls & Performance Settings", systemImage: "slider.horizontal.3")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                featureItem(title: "Resolution Downscaling", desc: "Lower the resolution in Settings (e.g. 1080p or 720p) to conserve Mac battery and CPU/GPU usage on Intel Macs.")
                featureItem(title: "Audio Forwarding", desc: "Streams phone audio directly to your Mac speakers or headphones (requires Android 11+).")
                featureItem(title: "Turn Screen Off", desc: "Turns off the physical phone screen backlight while keeping mirroring alive on your Mac to prevent phone overheating and save battery.")
                featureItem(title: "Stay Awake", desc: "Prevents your phone from locking while mirroring is active.")
            }
        }
        .cardStyled()
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Frequently Asked Questions (FAQ)", systemImage: "questionmark.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                faqItem(
                    q: "How do I connect wirelessly without plugging in USB every time?",
                    a: "Once TCP/IP mode is activated on your phone, you can connect directly at any time by entering your phone's Wi-Fi IP address in Connected Devices and clicking 'Connect Wi-Fi'."
                )
                Divider()
                faqItem(
                    q: "Why did clicking 'Stop Mirror' show an error previously?",
                    a: "This has been resolved in the latest update. Stopping a session now cleanly terminates scrcpy without displaying error dialogs."
                )
                Divider()
                faqItem(
                    q: "Can I transfer files to SD cards?",
                    a: "Yes! If your phone has a physical MicroSD card inserted, Macroid Eco automatically detects it and lists it in the Storage dropdown."
                )
                Divider()
                faqItem(
                    q: "Can I install Android apps (.apk files)?",
                    a: "Yes! While the mirroring window is active, drag and drop any .apk file directly onto the mirroring screen to install it on your device."
                )
            }
        }
        .cardStyled()
    }

    private var privacyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundColor(AppTheme.statusAuthorized)

            VStack(alignment: .leading, spacing: 2) {
                Text("100% Offline & Private")
                    .font(.headline)
                Text("Macroid Eco operates entirely on your local machine using standard open-source ADB and scrcpy protocols. No phone data, screens, or files are ever sent to external cloud servers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.elevatedSurface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    // MARK: - Item Helpers

    private func helpStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppTheme.electricBlue.opacity(0.18)))
                .foregroundColor(AppTheme.electricBlue)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func featureItem(title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(AppTheme.electricBlue)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func faqItem(q: String, a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(q)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(a)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
