import SwiftUI
import MacdroidMirrorCore

@main
struct MacdroidMirrorApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 620)
        .commands {
            SidebarCommands()
        }
    }
}
