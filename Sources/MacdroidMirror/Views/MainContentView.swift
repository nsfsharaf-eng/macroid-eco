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
                AppTheme.navyBackground
                    .ignoresSafeArea()

                switch viewModel.selectedSection {
                case .overview:
                    OverviewView(viewModel: viewModel)
                case .devices:
                    DevicesView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
                case .diagnostics:
                    DiagnosticsView(viewModel: viewModel)
                case .troubleshooting:
                    TroubleshootingView()
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Macdroid Mirror"),
                message: Text(viewModel.alertMessage ?? "An unexpected event occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            await viewModel.checkDependencies()
        }
    }
}
