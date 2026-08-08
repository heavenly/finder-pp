import Foundation
import Observation

@MainActor
@Observable
final class FavoritesStore {
    private static let defaultsKey = "favoritePaths"
    private static let appDefaults = UserDefaults(suiteName: "com.sanjayk.ExplorerPP") ?? .standard

    private(set) var urls: [URL]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = FavoritesStore.appDefaults) {
        self.defaults = defaults
        if defaults.stringArray(forKey: Self.defaultsKey) == nil {
            let legacyDefaults = UserDefaults(suiteName: "Explorer")
            let legacyPaths = legacyDefaults?.stringArray(forKey: Self.defaultsKey)
                ?? UserDefaults.standard.stringArray(forKey: Self.defaultsKey)
            if let legacyPaths {
                defaults.set(legacyPaths, forKey: Self.defaultsKey)
            }
        }
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
