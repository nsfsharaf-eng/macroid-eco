import SwiftUI
import MacdroidMirrorCore

public struct DiagnosticsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isAuditing: Bool = false
    @State private var copiedToClipboard: Bool = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Diagnostics")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Verify runtime dependencies, hardware architecture, and diagnostic reports.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        copyDiagnosticReport()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            Text(copiedToClipboard ? "Copied" : "Copy Report")
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            isAuditing = true
                            await viewModel.checkDependencies()
                            isAuditing = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isAuditing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Re-scan System")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.electricBlue)
                }

                // Dependency Cards
                adbDiagnosticsCard
                scrcpyDiagnosticsCard

                // Environment & Host Architecture Card
                environmentAuditCard
            }
            .padding(24)
        }
    }

    // MARK: - Subviews

    private var adbDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal")
                    .font(.title3)
                    .foregroundColor(AppTheme.electricBlue)
                Text("Android Debug Bridge (ADB)")
                    .font(.headline)

                Spacer()

                statusPill(for: viewModel.dependencies.adb)
            }

            Divider()

            switch viewModel.dependencies.adb {
            case .available(let path, let version):
                VStack(alignment: .leading, spacing: 6) {
                    detailRow(label: "Executable Path", value: path, monospaced: true)
                    if let version = version {
                        detailRow(label: "Version Output", value: version, monospaced: true)
                    }
                }
            case .missing(let searched):
                VStack(alignment: .leading, spacing: 6) {
                    Text("ADB was not detected in any of the standard candidate paths:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(searched, id: \.self) { path in
                            Text("• \(path)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Installation command:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("brew install android-platform-tools")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .padding(.top, 4)
                }
            case .permissionDenied(let path):
                Text("Permission denied when trying to execute \(path). Please check file permissions.")
                    .font(.caption)
                    .foregroundColor(AppTheme.statusError)
            case .executionError(let msg):
                Text("Execution error: \(msg)")
                    .font(.caption)
                    .foregroundColor(AppTheme.statusError)
            case .checking:
                ProgressView("Searching for ADB executable…")
                    .controlSize(.small)
            }
        }
        .cardStyled()
    }

    private var scrcpyDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "display")
                    .font(.title3)
                    .foregroundColor(AppTheme.electricBlue)
                Text("scrcpy Display Engine")
                    .font(.headline)

                Spacer()

                statusPill(for: viewModel.dependencies.scrcpy)
            }

            Divider()

            switch viewModel.dependencies.scrcpy {
            case .available(let path, let version):
                VStack(alignment: .leading, spacing: 6) {
                    detailRow(label: "Executable Path", value: path, monospaced: true)
                    if let version = version {
                        detailRow(label: "Version Output", value: version, monospaced: true)
                    }
                }
            case .missing(let searched):
                VStack(alignment: .leading, spacing: 6) {
                    Text("scrcpy was not detected in any of the standard candidate paths:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(searched, id: \.self) { path in
                            Text("• \(path)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Installation command:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("brew install scrcpy")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .padding(.top, 4)
                }
            case .permissionDenied(let path):
                Text("Permission denied executing \(path).")
                    .font(.caption)
                    .foregroundColor(AppTheme.statusError)
            case .executionError(let msg):
                Text("Execution error: \(msg)")
                    .font(.caption)
                    .foregroundColor(AppTheme.statusError)
            case .checking:
                ProgressView("Searching for scrcpy executable…")
                    .controlSize(.small)
            }
        }
        .cardStyled()
    }

    private var environmentAuditCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .font(.title3)
                    .foregroundColor(AppTheme.electricBlue)
                Text("Host System Environment")
                    .font(.headline)

                Spacer()

                Text("Verified")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.statusAuthorized.opacity(0.15)))
                    .foregroundColor(AppTheme.statusAuthorized)
            }

            Divider()

            let osVer = ProcessInfo.processInfo.operatingSystemVersionString
            let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)

            VStack(alignment: .leading, spacing: 6) {
                detailRow(label: "Operating System", value: osVer)
                detailRow(label: "Target Architecture", value: "Intel x86_64 (First-Class Support)")
                detailRow(label: "Physical Memory", value: String(format: "%.1f GB RAM", memoryGB))
                detailRow(label: "Active Devices Count", value: "\(viewModel.devices.count)")
            }
        }
        .cardStyled()
    }

    private func detailRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            if monospaced {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
    }

    private func statusPill(for status: DependencyStatus) -> some View {
        Text(status.statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
            .foregroundColor(statusColor(status))
    }

    private func statusColor(_ status: DependencyStatus) -> Color {
        switch status {
        case .available: return AppTheme.statusAuthorized
        case .missing: return AppTheme.statusUnauthorized
        case .permissionDenied, .executionError: return AppTheme.statusError
        case .checking: return .secondary
        }
    }

    private func copyDiagnosticReport() {
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        let mem = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let report = """
        === Macroid Eco Diagnostic Report ===
        OS: \(osVer)
        Architecture: x86_64
        Memory: \(String(format: "%.1f GB", mem))
        ADB Status: \(viewModel.dependencies.adb.statusText) [\(viewModel.dependencies.adb.path ?? "None")]
        scrcpy Status: \(viewModel.dependencies.scrcpy.statusText) [\(viewModel.dependencies.scrcpy.path ?? "None")]
        Devices Detected: \(viewModel.devices.count)
        Selected Device: \(viewModel.selectedDevice?.displayName ?? "None") (\(viewModel.selectedDevice?.state.title ?? "N/A"))
        Session State: \(viewModel.sessionManager.state.statusDescription)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)

        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}
