import Foundation

public enum CatalogEndpoints {
    /// Public JSON manifest of released tracks. Override it in the app when the file lives somewhere else.
    public static let defaultManifestURL = URL(string: "https://matthewfinley.org/music/manifest.json")!
    /// Historical public catalog profile. The path is the account slug the feed is published under.
    public static let soundCloudProfileURL = URL(string: "https://soundcloud.com/sonicrift")!

    public static func oEmbedURL(for profile: URL = soundCloudProfileURL) -> URL? {
        var components = URLComponents(string: "https://soundcloud.com/oembed")
        components?.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "url", value: profile.absoluteString),
        ]
        return components?.url
    }
}

public struct CatalogSnapshot: Equatable, Sendable {
    public var tracks: [Track]
    public var newDropIDs: [String]
    public var errors: [String]

    public init(tracks: [Track], newDropIDs: [String], errors: [String] = []) {
        self.tracks = tracks
        self.newDropIDs = newDropIDs
        self.errors = errors
    }
}

public enum CatalogMerger {
    public static func merge(_ groups: [[Track]]) -> [Track] {
        var seenIDs = Set<String>()
        var seenLinks = Set<String>()
        var merged: [Track] = []
        for group in groups {
            for track in group {
                if seenIDs.contains(track.id) { continue }
                let link = track.placeholder ? "" : track.permalink
                if !link.isEmpty && seenLinks.contains(link) { continue }
                seenIDs.insert(track.id)
                if !link.isEmpty { seenLinks.insert(link) }
                merged.append(track)
            }
        }
        return merged.sorted { lhs, rhs in
            if lhs.placeholder != rhs.placeholder { return !lhs.placeholder && rhs.placeholder }
            let left = lhs.releasedAt?.timeIntervalSince1970 ?? 0
            let right = rhs.releasedAt?.timeIntervalSince1970 ?? 0
            if left != right { return left > right }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

public enum NewDrops {
    public static let window: TimeInterval = 21 * 24 * 60 * 60

    public static func select(tracks: [Track], now: Date) -> [String] {
        let ranked = tracks
            .filter { !$0.placeholder }
            .compactMap { track -> (id: String, released: TimeInterval, include: Bool)? in
                let released = track.releasedAt?.timeIntervalSince1970
                let recent: Bool
                if let released {
                    let age = now.timeIntervalSince1970 - released
                    recent = age >= 0 && age <= window
                } else {
                    recent = false
                }
                let include = track.newDrop || recent
                guard include else { return nil }
                return (track.id, released ?? 0, true)
            }
            .sorted { $0.released > $1.released }
        return ranked.map(\.id)
    }
}

public struct SoundCloudSnapshotFile: Equatable, Sendable {
    public var capturedAt: String?
    public var note: String?
    public var tracks: [Track]

    public init(capturedAt: String?, note: String?, tracks: [Track]) {
        self.capturedAt = capturedAt
        self.note = note
        self.tracks = tracks
    }
}

public enum SoundCloudSnapshot {
    public static func parse(_ data: Data, sourceID: String = "soundcloud-snapshot") throws -> SoundCloudSnapshotFile {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let record = json as? [String: Any] else {
            throw ManifestError("Catalog snapshot must be a JSON object.")
        }
        guard let rawTracks = record["tracks"] as? [Any] else {
            throw ManifestError("Catalog snapshot is missing tracks.")
        }
        let tracks: [Track] = rawTracks.compactMap { entry in
            guard let item = entry as? [String: Any],
                  let id = item["id"] as? String,
                  let title = item["title"] as? String,
                  let permalink = item["permalink"] as? String,
                  let stream = item["streamUrl"] as? String else { return nil }
            let details = item["description"] as? String ?? ""
            guard !ThirdPartyFilter.isThirdParty(title: title, details: details) else { return nil }
            return Track(
                id: "soundcloud:\(id)",
                title: title,
                artist: ArtistName.display,
                permalink: permalink,
                details: details,
                artworkURL: item["artworkUrl"] as? String,
                releasedAt: ManifestParser.parseDate(item["releasedAt"] as? String),
                durationMs: (item["durationMs"] as? Int) ?? (item["durationMs"] as? Double).map { Int($0) },
                sourceID: sourceID,
                placeholder: false,
                playback: .remote(url: stream)
            )
        }
        return SoundCloudSnapshotFile(
            capturedAt: record["capturedAt"] as? String,
            note: record["note"] as? String,
            tracks: tracks
        )
    }
}
