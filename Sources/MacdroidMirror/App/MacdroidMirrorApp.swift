import SwiftUI
import AppKit
import MacdroidMirrorCore
import ObjectiveC.runtime

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApplication.swizzleShowHelpOnce
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    @objc func showHelp(_ sender: Any?) {
        openMacroidEcoHelp()
    }
}

extension NSApplication {
    static let swizzleShowHelpOnce: Void = {
        let originalSelector = #selector(NSApplication.showHelp(_:))
        let swizzledSelector = #selector(NSApplication.mm_showHelp(_:))

        guard let originalMethod = class_getInstanceMethod(NSApplication.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSApplication.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func mm_showHelp(_ sender: Any?) {
        DispatchQueue.main.async {
            openMacroidEcoHelp()
        }
    }
}

@MainActor
func openMacroidEcoHelp() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.canBecomeKey && !($0 is NSPanel) }) {
        window.makeKeyAndOrderFront(nil)
    }
    AppViewModel.navigate(to: .help)
}

@MainActor
func openMacroidEcoTroubleshooting() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.canBecomeKey && !($0 is NSPanel) }) {
        window.makeKeyAndOrderFront(nil)
    }
    AppViewModel.navigate(to: .troubleshooting)
}

@main
struct MacroidEcoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 620)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .help) {
                Button("Macroid Eco Help") {
                    openMacroidEcoHelp()
                }
                .keyboardShortcut("?", modifiers: .command)

                Button("Connection & Troubleshooting Guide") {
                    openMacroidEcoTroubleshooting()
                }

                Divider()

                Button("USB Debugging Setup Guide") {
                    openMacroidEcoTroubleshooting()
                }
            }
        }
    }
}
