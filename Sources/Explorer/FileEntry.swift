import Foundation

struct FileEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?

    var id: URL { url }
    var name: String { url.lastPathComponent }

    var kind: String {
        if isDirectory {
            return "Folder"
        }

        let fileExtension = url.pathExtension
        return fileExtension.isEmpty ? "File" : "\(fileExtension.uppercased()) file"
    }

    var formattedSize: String {
        guard !isDirectory, let size else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        guard let modificationDate else { return "" }
        return modificationDate.formatted(date: .numeric, time: .shortened)
    }
}
