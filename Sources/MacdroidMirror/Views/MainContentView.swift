import SwiftUI
import MacdroidMirrorCore

@MainActor
public struct MainContentView: View {
    @StateObject private var viewModel = AppViewModel()

    public init() {}

    public init(viewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ZStack {
                AppTheme.windowBackground
                    .ignoresSafeArea()

                switch viewModel.selectedSection {
                case .overview:
                    OverviewView(viewModel: viewModel)
                case .devices:
                    DevicesView(viewModel: viewModel)
                case .fileTransfer:
                    FileTransferView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
                case .diagnostics:
                    DiagnosticsView(viewModel: viewModel)
                case .troubleshooting:
                    TroubleshootingView()
                case .help:
                    HelpView(viewModel: viewModel)
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Macroid Eco"),
                message: Text(viewModel.alertMessage ?? "An unexpected event occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNavigationSection)) { notification in
            if let raw = notification.userInfo?["section"] as? String, let section = NavigationSection(rawValue: raw) {
                viewModel.selectedSection = section
            } else if let section = notification.userInfo?["section"] as? NavigationSection {
                viewModel.selectedSection = section
            }
        }
        .task {
            await viewModel.checkDependencies()
        }
    }
}
