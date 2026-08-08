import AppKit
import SwiftUI

@main
struct ExplorerApp: App {
    @NSApplicationDelegateAdaptor(ExplorerAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Explorer", id: "browser") {
            BrowserView()
        }
        .defaultSize(width: 1_050, height: 680)
        .commands {
            ExplorerCommands()
        }
    }
}

private final class ExplorerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct ExplorerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Explorer Window") {
                openWindow(id: "browser")
            }
            .keyboardShortcut("e", modifiers: .command)
        }
    }
}
