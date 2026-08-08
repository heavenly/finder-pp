import AppKit
import Foundation
import Observation

enum FileSortColumn {
    case name
    case modificationDate
    case kind
    case size
}

extension Notification.Name {
    static let explorerFilesDidMove = Notification.Name("ExplorerPPFilesDidMove")
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
    var searchText = ""
    var isFindPresented = false
    var sortColumn: FileSortColumn = .name
    var sortAscending = true
    let pasteboard: NSPasteboard

    init(
        startingAt url: URL = FileManager.default.homeDirectoryForCurrentUser,
        pasteboard: NSPasteboard = .general
    ) {
        currentURL = url.standardizedFileURL
        self.pasteboard = pasteboard
        reload()
    }

    var canGoBack: Bool { !backHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }
    var canGoUp: Bool { currentURL.path != "/" }
    func visibleEntries(folderSizes: [String: Int64]) -> [FileEntry] {
        let filteredEntries = searchText.isEmpty ? entries : entries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return filteredEntries.sorted {
            compare($0, $1, folderSizes: folderSizes)
        }
    }

    func selectSortColumn(_ column: FileSortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }

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
        searchText = ""
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
        searchText = ""
        selectedURLs.removeAll()
        reload()
    }

    func goForward() {
        guard let destination = forwardHistory.popLast() else { return }
        backHistory.append(currentURL)
        currentURL = destination
        searchText = ""
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

    func open(_ url: URL, with applicationURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.errorMessage = "Could not open “\(url.lastPathComponent)” with “\(applicationURL.deletingPathExtension().lastPathComponent)”.\n\(error.localizedDescription)"
            }
        }
    }

    func beginFind() {
        isFindPresented = true
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

    private func compare(
        _ left: FileEntry,
        _ right: FileEntry,
        folderSizes: [String: Int64]
    ) -> Bool {
        if left.isDirectory != right.isDirectory {
            return left.isDirectory
        }

        let result: ComparisonResult
        switch sortColumn {
        case .name:
            result = left.name.localizedStandardCompare(right.name)
        case .modificationDate:
            result = compare(left.modificationDate ?? .distantPast, right.modificationDate ?? .distantPast)
        case .kind:
            result = left.kind.localizedStandardCompare(right.kind)
        case .size:
            let leftSize = left.isDirectory
                ? folderSizes[left.url.standardizedFileURL.path] ?? -1
                : left.size ?? -1
            let rightSize = right.isDirectory
                ? folderSizes[right.url.standardizedFileURL.path] ?? -1
                : right.size ?? -1
            result = compare(leftSize, rightSize)
        }

        if result == .orderedSame, sortColumn != .name {
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
        return sortAscending ? result == .orderedAscending : result == .orderedDescending
    }

    private func compare<T: Comparable>(_ left: T, _ right: T) -> ComparisonResult {
        if left < right { return .orderedAscending }
        if left > right { return .orderedDescending }
        return .orderedSame
    }
}
