import AppKit
import Foundation
import SwiftUI

extension BrowserModel {
    var canRename: Bool { selectedURLs.count == 1 }
    var hasSelection: Bool { !selectedURLs.isEmpty }

    func createFolder(named rawName: String) {
        guard let name = validFileName(rawName) else { return }
        let destination = currentURL.appendingPathComponent(name, isDirectory: true)

        do {
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            selectedURLs = [destination]
            notifyFileChange()
        } catch {
            report(error, action: "create the folder “\(name)”")
        }
    }

    func renameSelectedItem(to rawName: String) {
        guard let source = selectedURLs.first, selectedURLs.count == 1 else { return }
        guard let name = validFileName(rawName) else { return }

        let destination = source.deletingLastPathComponent().appendingPathComponent(name)
        guard destination != source else { return }

        do {
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.moveItem(at: source, to: destination)
            selectedURLs = [destination]
            notifyFileChange()
        } catch {
            report(error, action: "rename “\(source.lastPathComponent)”")
        }
    }

    func moveSelectedItemsToTrash() {
        guard hasSelection else { return }

        for source in selectedURLs.sorted(by: { $0.path < $1.path }) {
            do {
                try FileManager.default.trashItem(at: source, resultingItemURL: nil)
            } catch {
                report(error, action: "move “\(source.lastPathComponent)” to the Trash")
                break
            }
        }

        selectedURLs.removeAll()
        notifyFileChange()
    }

    func copySelectedItems() {
        writeSelectionToPasteboard(isCut: false)
    }

    func cutSelectedItems() {
        writeSelectionToPasteboard(isCut: true)
    }

    func pasteItems(to destinationDirectory: URL? = nil) {
        let targetDirectory = destinationDirectory ?? currentURL
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        let sources = objects.compactMap { object -> URL? in
            guard let url = object as? NSURL else { return nil }
            return url as URL
        }
        guard !sources.isEmpty else { return }

        let isCut = pasteboard.string(forType: .explorerCutFiles) == "cut"
        var completedURLs: Set<URL> = []

        for source in sources {
            let destination = targetDirectory.appendingPathComponent(source.lastPathComponent)

            do {
                guard source.standardizedFileURL != destination.standardizedFileURL else {
                    throw CocoaError(.fileWriteFileExists)
                }
                guard !FileManager.default.fileExists(atPath: destination.path) else {
                    throw CocoaError(.fileWriteFileExists)
                }

                if isCut {
                    try FileManager.default.moveItem(at: source, to: destination)
                } else {
                    try FileManager.default.copyItem(at: source, to: destination)
                }
                completedURLs.insert(destination)
            } catch {
                report(error, action: "paste “\(source.lastPathComponent)”")
                break
            }
        }

        if !completedURLs.isEmpty {
            selectedURLs = completedURLs
            if isCut {
                pasteboard.clearContents()
            }
            notifyFileChange()
        }
    }

    private func writeSelectionToPasteboard(isCut: Bool) {
        guard hasSelection else { return }

        pasteboard.clearContents()
        pasteboard.writeObjects(selectedURLs.sorted(by: { $0.path < $1.path }).map { $0 as NSURL })

        if isCut {
            pasteboard.setString("cut", forType: .explorerCutFiles)
        }
    }

    private func validFileName(_ rawName: String) -> String? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            errorMessage = "Enter a name that does not contain a slash."
            return nil
        }
        return name
    }

    private func report(_ error: Error, action: String) {
        errorMessage = "Could not \(action).\n\(error.localizedDescription)"
    }

    private func notifyFileChange() {
        NotificationCenter.default.post(name: .explorerFilesDidMove, object: nil)
    }
}

extension NSPasteboard.PasteboardType {
    static let explorerCutFiles = NSPasteboard.PasteboardType("works.earendil.explorer.cut-files")
}

@MainActor
enum FileNamePrompt {
    static func show(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(string: defaultValue)
        textField.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return textField.stringValue
    }
}

struct FocusedBrowserModelKey: FocusedValueKey {
    typealias Value = BrowserModel
}

extension FocusedValues {
    var browserModel: BrowserModel? {
        get { self[FocusedBrowserModelKey.self] }
        set { self[FocusedBrowserModelKey.self] = newValue }
    }
}
