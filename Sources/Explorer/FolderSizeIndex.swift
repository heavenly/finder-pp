import Foundation
import Observation

struct FolderSizeRecord: Codable {
    let size: Int64
    let modificationDate: Date?
    let scannedAt: Date
}

enum FolderSizeCalculator {
    static func size(of folderURL: URL) throws -> Int64 {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

@MainActor
@Observable
final class FolderSizeIndex {
    private struct ScanRequest {
        let url: URL
        let modificationDate: Date?
    }

    private(set) var records: [String: FolderSizeRecord]
    private(set) var calculatingPaths: Set<String> = []

    private var queuedPaths: Set<String> = []
    private var queue: [ScanRequest] = []
    private var scanTask: Task<Void, Never>?

    private let indexURL: URL

    init(indexURL: URL? = nil) {
        self.indexURL = indexURL ?? Self.defaultIndexURL
        records = Self.load(from: self.indexURL)
        pruneOldRecords()
    }

    func index(_ entries: [FileEntry]) {
        for entry in entries where entry.isDirectory {
            let path = entry.url.standardizedFileURL.path
            if let record = records[path], record.modificationDate == entry.modificationDate {
                continue
            }
            enqueue(entry.url, modificationDate: entry.modificationDate)
        }
        startNextScanIfNeeded()
    }

    func recalculate(_ entry: FileEntry) {
        guard entry.isDirectory else { return }
        let path = entry.url.standardizedFileURL.path
        records.removeValue(forKey: path)
        guard !calculatingPaths.contains(path), !queuedPaths.contains(path) else { return }
        queue.insert(ScanRequest(url: entry.url, modificationDate: entry.modificationDate), at: 0)
        queuedPaths.insert(path)
        startNextScanIfNeeded()
    }

    func formattedSize(for entry: FileEntry) -> String {
        guard entry.isDirectory else { return entry.formattedSize }
        let path = entry.url.standardizedFileURL.path

        if calculatingPaths.contains(path) {
            return "Calculating…"
        }
        if let record = records[path], record.modificationDate == entry.modificationDate {
            return ByteCountFormatter.string(fromByteCount: record.size, countStyle: .file)
        }
        return "Waiting…"
    }

    private func enqueue(_ url: URL, modificationDate: Date?) {
        let path = url.standardizedFileURL.path
        guard !calculatingPaths.contains(path), !queuedPaths.contains(path) else { return }
        queue.append(ScanRequest(url: url, modificationDate: modificationDate))
        queuedPaths.insert(path)
    }

    private func startNextScanIfNeeded() {
        guard scanTask == nil, !queue.isEmpty else { return }

        let request = queue.removeFirst()
        let path = request.url.standardizedFileURL.path
        queuedPaths.remove(path)
        calculatingPaths.insert(path)

        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result { try FolderSizeCalculator.size(of: request.url) }
            }.value

            guard let self else { return }
            calculatingPaths.remove(path)

            if case let .success(size) = result {
                records[path] = FolderSizeRecord(
                    size: size,
                    modificationDate: request.modificationDate,
                    scannedAt: .now
                )
                save()
            }

            scanTask = nil
            startNextScanIfNeeded()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: indexURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            // Folder sizes are an optional cache. File browsing must continue if saving fails.
        }
    }

    private func pruneOldRecords() {
        let cutoff = Date.now.addingTimeInterval(-90 * 24 * 60 * 60)
        records = records.filter { $0.value.scannedAt >= cutoff }
    }

    private static func load(from url: URL) -> [String: FolderSizeRecord] {
        guard let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([String: FolderSizeRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    private static var defaultIndexURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Explorer", isDirectory: true)
            .appendingPathComponent("folder-sizes.json")
    }
}
