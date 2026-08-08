import AppKit
import Observation
import QuickLookThumbnailing
import UniformTypeIdentifiers

@MainActor
@Observable
final class MediaThumbnailStore {
    private(set) var thumbnails: [String: NSImage] = [:]
    private var requestedKeys: Set<String> = []

    func thumbnail(for entry: FileEntry) -> NSImage? {
        thumbnails[cacheKey(for: entry)]
    }

    func loadThumbnail(for entry: FileEntry) async {
        guard supportsThumbnail(entry) else { return }
        let key = cacheKey(for: entry)
        guard thumbnails[key] == nil, requestedKeys.insert(key).inserted else { return }

        let request = QLThumbnailGenerator.Request(
            fileAt: entry.url,
            size: CGSize(width: 64, height: 64),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: [.lowQualityThumbnail, .thumbnail]
        )
        request.iconMode = false

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            thumbnails[key] = representation.nsImage
            trimCacheIfNeeded()
        } catch {
            // Unsupported or unreadable media keeps its normal file icon.
        }
    }

    func supportsThumbnail(_ entry: FileEntry) -> Bool {
        guard !entry.isDirectory,
              let type = UTType(filenameExtension: entry.url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
            || type.conforms(to: .movie)
            || type.conforms(to: .audio)
    }

    private func cacheKey(for entry: FileEntry) -> String {
        "\(entry.url.standardizedFileURL.path)|\(entry.modificationDate?.timeIntervalSinceReferenceDate ?? 0)"
    }

    private func trimCacheIfNeeded() {
        while thumbnails.count > 500, let key = thumbnails.keys.first {
            thumbnails.removeValue(forKey: key)
            requestedKeys.remove(key)
        }
    }
}
