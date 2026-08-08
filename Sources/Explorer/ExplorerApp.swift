import AppKit
import SwiftUI

@main
struct ExplorerApp: App {
    @NSApplicationDelegateAdaptor(ExplorerAppDelegate.self) private var appDelegate
    @State private var favorites = FavoritesStore()
    @State private var folderSizeIndex = FolderSizeIndex()

    var body: some Scene {
        WindowGroup("Explorer", id: "browser") {
            BrowserView()
                .environment(favorites)
                .environment(folderSizeIndex)
                .preferredColorScheme(nil)
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
    @FocusedValue(\.browserModel) private var browserModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Explorer Window") {
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
