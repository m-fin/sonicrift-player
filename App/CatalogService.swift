import Foundation
import PlayerCore

enum CatalogService {
    static func loadBundled() -> [Track] {
        guard let url = Bundle.main.url(forResource: "bundled-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? ManifestParser.parse(data) else {
            return []
        }
        return manifest.tracks
    }

    static func loadSnapshot() -> [Track] {
        guard let url = Bundle.main.url(forResource: "soundcloud-snapshot", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let snapshot = try? SoundCloudSnapshot.parse(data) else {
            return []
        }
        return snapshot.tracks
    }

    static func loadRemoteManifest(from url: URL) async -> [Track] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let manifest = try? ManifestParser.parse(data) else {
            return []
        }
        return manifest.tracks
    }

    static func loadSoundCloud(profile: URL = CatalogEndpoints.soundCloudProfileURL) async throws -> [Track] {
        guard let oEmbedURL = CatalogEndpoints.oEmbedURL(for: profile) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: oEmbedURL)
        let profileJSON = try JSONSerialization.jsonObject(with: data)
        let embed = SoundCloudFeed.readOEmbed(profileJSON)
        guard let html = embed.html,
              let userID = SoundCloudFeed.userID(fromWidgetHTML: html),
              var page = SoundCloudFeed.rssURL(forUserID: userID) else {
            throw URLError(.cannotParseResponse)
        }
        var items: [RSSTrack] = []
        var seen = Set<String>()
        for _ in 0..<5 {
            if seen.contains(page.absoluteString) { break }
            seen.insert(page.absoluteString)
            let (pageData, _) = try await URLSession.shared.data(from: page)
            guard let xml = String(data: pageData, encoding: .utf8) else { break }
            items.append(contentsOf: SoundCloudFeed.parseRSS(xml))
            guard let next = SoundCloudFeed.nextPage(in: xml), let nextURL = URL(string: next) else { break }
            page = nextURL
        }
        return SoundCloudFeed.tracks(from: items)
    }
}

enum SuiteStore {
    static let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    static let manifestKey = "mf.manifestURL"
    static let favoritesKey = "mf.favorites"
    static let generativeKey = "mf.generative"

    static func loadFavorites() -> FavoritesStore {
        guard let data = defaults.data(forKey: favoritesKey),
              let store = try? JSONDecoder().decode(FavoritesStore.self, from: data) else {
            return FavoritesStore()
        }
        return store
    }

    static func saveFavorites(_ store: FavoritesStore) {
        if let data = try? JSONEncoder().encode(store) {
            defaults.set(data, forKey: favoritesKey)
        }
    }

    static func saveSnapshot(_ snapshot: NowPlayingSnapshot) {
        if let data = try? NowPlayingSnapshot.encode(snapshot) {
            defaults.set(data, forKey: NowPlayingSnapshot.defaultsKey)
        }
    }
}
