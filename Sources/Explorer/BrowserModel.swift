import AppKit
import Foundation
import Observation

extension Notification.Name {
    static let explorerFilesDidMove = Notification.Name("ExplorerFilesDidMove")
}

@MainActor
@Observable
final class BrowserModel {
    private(set) var currentURL: URL
    private(set) var entries: [FileEntry] = []
    private(set) var backHistory: [URL] = []
    private(set) var forwardHistory: [URL] = []
    var selectedURLs: Set<URL> = []
    var errorMessage: String?

    init(startingAt url: URL = FileManager.default.homeDirectoryForCurrentUser) {
        currentURL = url.standardizedFileURL
        reload()
    }

    var canGoBack: Bool { !backHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }
    var canGoUp: Bool { currentURL.path != "/" }

    func navigate(to url: URL) {
        let destination = url.standardizedFileURL
        guard destination != currentURL else { return }
        guard isDirectory(destination) else {
            open(destination)
            return
        }

        backHistory.append(currentURL)
        forwardHistory.removeAll()
        currentURL = destination
        selectedURLs.removeAll()
        reload()
    }

    func navigate(toPath path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let destination = URL(fileURLWithPath: expandedPath).standardizedFileURL
        guard isDirectory(destination) else {
            errorMessage = "The path is not an accessible folder:\n\(expandedPath)"
            return
        }
        navigate(to: destination)
    }

    func goBack() {
        guard let destination = backHistory.popLast() else { return }
        forwardHistory.append(currentURL)
        currentURL = destination
        selectedURLs.removeAll()
        reload()
    }

    func goForward() {
        guard let destination = forwardHistory.popLast() else { return }
        backHistory.append(currentURL)
        currentURL = destination
        selectedURLs.removeAll()
        reload()
    }

    func goUp() {
        navigate(to: currentURL.deletingLastPathComponent())
    }

    func open(_ url: URL) {
        if isDirectory(url) {
            navigate(to: url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    func move(_ urls: [URL], to destinationDirectory: URL) -> Bool {
        var movedAnyItem = false

        for source in urls {
            let source = source.standardizedFileURL
            let destination = destinationDirectory
                .appendingPathComponent(source.lastPathComponent)
                .standardizedFileURL

            guard source != destination else { continue }
            guard source.deletingLastPathComponent() != destinationDirectory.standardizedFileURL else {
                continue
            }

            do {
                guard !FileManager.default.fileExists(atPath: destination.path) else {
                    throw CocoaError(.fileWriteFileExists)
                }
                try FileManager.default.moveItem(at: source, to: destination)
                movedAnyItem = true
            } catch {
                errorMessage = "Could not move “\(source.lastPathComponent)” to “\(destinationDirectory.lastPathComponent)”.\n\(error.localizedDescription)"
                break
            }
        }

        if movedAnyItem {
            NotificationCenter.default.post(name: .explorerFilesDidMove, object: nil)
        }
        return movedAnyItem
    }

    func reload() {
        do {
            let keys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .isHiddenKey
            ]
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentURL,
                includingPropertiesForKeys: Array(keys),
                options: []
            )

            entries = try urls.compactMap { url in
                let values = try url.resourceValues(forKeys: keys)
                guard values.isHidden != true else { return nil }
                return FileEntry(
                    url: url,
                    isDirectory: values.isDirectory == true,
                    size: values.fileSize.map(Int64.init),
                    modificationDate: values.contentModificationDate
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory {
                    return $0.isDirectory
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            entries = []
            errorMessage = "Could not read “\(currentURL.path)”.\n\(error.localizedDescription)"
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
