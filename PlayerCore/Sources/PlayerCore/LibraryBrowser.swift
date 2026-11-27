import Foundation

public struct AlbumGroup: Equatable, Sendable, Identifiable {
    public var title: String
    public var tracks: [Track]

    public var id: String { title }

    public init(title: String, tracks: [Track]) {
        self.title = title
        self.tracks = tracks
    }
}

public struct FavoritesStore: Codable, Equatable, Sendable {
    public private(set) var ids: [String]

    public init(ids: [String] = []) {
        self.ids = ids
    }

    public func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    public mutating func toggle(_ id: String) {
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
    }
}

public enum LibraryBrowser {
    public static let singlesTitle = "Singles"

    public static func latestDrops(in tracks: [Track], now: Date) -> [Track] {
        let ids = NewDrops.select(tracks: tracks, now: now)
        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { lookup[$0] }
    }

    public static func albums(in tracks: [Track]) -> [AlbumGroup] {
        var buckets: [String: [Track]] = [:]
        var order: [String] = []
        for track in tracks {
            let title = track.album?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = (title?.isEmpty == false ? title! : singlesTitle)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(track)
        }
        let groups = order.map { AlbumGroup(title: $0, tracks: buckets[$0] ?? []) }
        return groups.sorted { lhs, rhs in
            if lhs.title == singlesTitle { return false }
            if rhs.title == singlesTitle { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    public static func tracks(_ tracks: [Track], mood: Mood) -> [Track] {
        tracks.filter { $0.resolvedMoods().contains(mood) }
    }

    public static func favorites(_ tracks: [Track], store: FavoritesStore) -> [Track] {
        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return store.ids.compactMap { lookup[$0] }
    }

    public static func onDevice(_ tracks: [Track], cache: OfflineCacheStore) -> [Track] {
        tracks.filter { isOnDevice($0, cache: cache) }
    }

    public static func applyingOfflineFilter(_ tracks: [Track], cache: OfflineCacheStore, offlineOnly: Bool) -> [Track] {
        guard offlineOnly else { return tracks }
        return onDevice(tracks, cache: cache)
    }

    public static func isOnDevice(_ track: Track, cache: OfflineCacheStore) -> Bool {
        track.isBundled || cache.contains(track.id)
    }
}
