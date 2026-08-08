import Foundation
import Observation

@MainActor
@Observable
final class FavoritesStore {
    private static let defaultsKey = "favoritePaths"

    private(set) var urls: [URL]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let paths = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        urls = paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
    }

    func contains(_ url: URL) -> Bool {
        urls.contains(url.standardizedFileURL)
    }

    func add(_ url: URL) {
        let url = url.standardizedFileURL
        guard !urls.contains(url) else { return }
        urls.append(url)
        save()
    }

    func remove(_ url: URL) {
        let url = url.standardizedFileURL
        urls.removeAll { $0 == url }
        save()
    }

    func toggle(_ url: URL) {
        if contains(url) {
            remove(url)
        } else {
            add(url)
        }
    }

    private func save() {
        defaults.set(urls.map(\.path), forKey: Self.defaultsKey)
    }
}
