import SwiftUI
import MacdroidMirrorCore

public struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Header
            HStack(spacing: 12) {
                AppLogoIconView(size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Macroid Eco")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("v0.1.0 • Intel x86_64")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .padding(.horizontal, 12)

            // Navigation Sections
            List(NavigationSection.allCases, selection: $viewModel.selectedSection) { section in
                NavigationLink(value: section) {
                    Label {
                        Text(section.rawValue)
                            .font(.body)
                    } icon: {
                        Image(systemName: section.iconName)
                            .foregroundColor(viewModel.selectedSection == section ? AppTheme.electricBlue : .secondary)
                    }
                }
                .tag(section)
            }
            .listStyle(.sidebar)

            Spacer()

            Divider()
                .padding(.horizontal, 12)

            // Important Message Card (Bottom Left Corner)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(AppTheme.electricBlue)
                        .font(.caption)
                    Text("Important Notice")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Text(sidebarImportantMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(AppTheme.elevatedSurface.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
            )
            .padding(12)
        }
        .frame(minWidth: 200, idealWidth: 220)
    }

    private var sidebarImportantMessage: String {
        if !viewModel.dependencies.allAvailable {
            return "Setup ADB and scrcpy in Diagnostics or Settings to enable mirroring."
        }
        if let device = viewModel.selectedDevice {
            if device.state == .unauthorized {
                return "Unlock phone screen and accept the RSA USB debugging authorization prompt."
            }
            if device.state == .offline {
                return "Device offline. Check your USB cable connection or restart ADB server."
            }
            return "Keep phone unlocked during active mirroring and file transfers."
        }
        return "Turn ON USB or Wireless Debugging in Developer Options on your phone."
    }
}

public struct AppLogoIconView: View {
    public var size: CGFloat = 34

    public init(size: CGFloat = 34) {
        self.size = size
    }

    public var body: some View {
        if let icon = NSImage(named: NSImage.applicationIconName), icon.isValid {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .cornerRadius(size > 28 ? 8 : 6)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size > 28 ? 8 : 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 14/255, green: 122/255, blue: 254/255), Color(red: 3/255, green: 78/255, blue: 162/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                Image(systemName: "display.and.arrow.down")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
        }
    }
}