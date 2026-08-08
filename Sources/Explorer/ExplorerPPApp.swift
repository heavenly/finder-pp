import AppKit
import SwiftUI

@main
struct ExplorerPPApp: App {
    @NSApplicationDelegateAdaptor(ExplorerPPAppDelegate.self) private var appDelegate
    @State private var favorites = FavoritesStore()
    @State private var folderSizeIndex = FolderSizeIndex()
    @State private var mediaThumbnails = MediaThumbnailStore()

    var body: some Scene {
        WindowGroup("ExplorerPP", id: "browser") {
            BrowserView()
                .environment(favorites)
                .environment(folderSizeIndex)
                .environment(mediaThumbnails)
                .preferredColorScheme(nil)
                .modifier(WindowBridgeInstaller())
        }
        .defaultSize(width: 1_050, height: 680)
        .commands {
            ExplorerPPCommands()
        }
    }
}

@MainActor
private enum ExplorerPPWindowBridge {
    static var openWindow: (() -> Void)?
}

private struct WindowBridgeInstaller: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            ExplorerPPWindowBridge.openWindow = {
                openWindow(id: "browser")
            }
        }
    }
}

@MainActor
private final class ExplorerPPAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        Task { @MainActor in
            await Task.yield()
            updateActivationPolicy()
            if hasVisibleWindow {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        sender.setActivationPolicy(.regular)

        if let window = sender.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            ExplorerPPWindowBridge.openWindow?()
        }
        sender.activate(ignoringOtherApps: true)
        return false
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            await Task.yield()
            updateActivationPolicy()
        }
    }

    @MainActor
    private var hasVisibleWindow: Bool {
        NSApplication.shared.windows.contains { $0.isVisible && $0.canBecomeKey }
    }

    @MainActor
    private func updateActivationPolicy() {
        NSApplication.shared.setActivationPolicy(hasVisibleWindow ? .regular : .accessory)
    }
}

private struct ExplorerPPCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.browserModel) private var browserModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New ExplorerPP Window") {
                openWindow(id: "browser")
            }
            .keyboardShortcut("e", modifiers: .command)

            Divider()

            Button("New Folder") {
                createFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(browserModel == nil)

            Button("Rename") {
                renameSelectedItem()
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(browserModel?.canRename != true)
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                browserModel?.cutSelectedItems()
            }
            .keyboardShortcut("x", modifiers: .command)
            .disabled(browserModel?.hasSelection != true)

            Button("Copy") {
                browserModel?.copySelectedItems()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(browserModel?.hasSelection != true)

            Button("Paste") {
                browserModel?.pasteItems()
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(browserModel == nil)

            Button("Find") {
                browserModel?.beginFind()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(browserModel == nil)

            Divider()

            Button("Move to Trash") {
                browserModel?.moveSelectedItemsToTrash()
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(browserModel?.hasSelection != true)
        }
    }

    private func createFolder() {
        guard let browserModel else { return }
        guard let name = FileNamePrompt.show(
            title: "New Folder",
            message: "Enter a name for the new folder.",
            defaultValue: "New Folder"
        ) else { return }
        browserModel.createFolder(named: name)
    }

    private func renameSelectedItem() {
        guard let browserModel, let item = browserModel.selectedURLs.first else { return }
        guard let name = FileNamePrompt.show(
            title: "Rename",
            message: "Enter a new name for “\(item.lastPathComponent)”.",
            defaultValue: item.lastPathComponent
        ) else { return }
        browserModel.renameSelectedItem(to: name)
    }
}
