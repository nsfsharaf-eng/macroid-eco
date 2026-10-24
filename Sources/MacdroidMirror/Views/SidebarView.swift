import SwiftUI
import MacdroidMirrorCore

public struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.electricBlue)
                        .frame(width: 32, height: 32)
                    Image(systemName: "display.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Macdroid Mirror")
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

            // System Readiness Indicator Footer
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.dependencies.allAvailable ? AppTheme.statusAuthorized : AppTheme.statusUnauthorized)
                        .frame(width: 8, height: 8)
                    Text(viewModel.dependencies.allAvailable ? "Dependencies Ready" : "Setup Required")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label("ADB", systemImage: viewModel.dependencies.adb.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.caption2)
                        .foregroundColor(viewModel.dependencies.adb.isAvailable ? AppTheme.statusAuthorized : .secondary)

                    Label("scrcpy", systemImage: viewModel.dependencies.scrcpy.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.caption2)
                        .foregroundColor(viewModel.dependencies.scrcpy.isAvailable ? AppTheme.statusAuthorized : .secondary)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 200, idealWidth: 220)
    }
}
