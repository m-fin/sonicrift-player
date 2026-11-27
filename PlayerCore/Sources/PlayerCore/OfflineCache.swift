import Foundation

public enum OfflineAudioLocation {
    public static let directoryName = "OfflineAudio"

    public static func relativePath(for trackID: String) -> String {
        let safe = String(trackID.map { character in
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                return character
            }
            return "_"
        })
        let stem = safe.isEmpty ? "track" : safe
        return "\(directoryName)/\(stem).audio"
    }
}

public struct OfflineRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var relativePath: String
    public var byteCount: Int64
    public var downloadedAt: Date
    public var playlistIDs: [String]

    public init(id: String, relativePath: String, byteCount: Int64, downloadedAt: Date, playlistIDs: [String] = []) {
        self.id = id
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.downloadedAt = downloadedAt
        self.playlistIDs = playlistIDs
    }
}

public struct OfflineCacheStore: Codable, Equatable, Sendable {
    public private(set) var records: [OfflineRecord]

    public init(records: [OfflineRecord] = []) {
        self.records = records
    }

    public var totalBytes: Int64 {
        records.reduce(0) { $0 + max(0, $1.byteCount) }
    }

    public func contains(_ trackID: String) -> Bool {
        records.contains { $0.id == trackID }
    }

    public func record(for trackID: String) -> OfflineRecord? {
        records.first { $0.id == trackID }
    }

    public func records(inPlaylist playlistID: String) -> [OfflineRecord] {
        records.filter { $0.playlistIDs.contains(playlistID) }
    }

    public mutating func markDownloaded(
        trackID: String,
        byteCount: Int64,
        downloadedAt: Date,
        playlistID: String? = nil
    ) {
        let path = OfflineAudioLocation.relativePath(for: trackID)
        if let index = records.firstIndex(where: { $0.id == trackID }) {
            var record = records[index]
            record.relativePath = path
            record.byteCount = byteCount
            record.downloadedAt = downloadedAt
            if let playlistID, !record.playlistIDs.contains(playlistID) {
                record.playlistIDs.append(playlistID)
            }
            records[index] = record
        } else {
            records.append(
                OfflineRecord(
                    id: trackID,
                    relativePath: path,
                    byteCount: byteCount,
                    downloadedAt: downloadedAt,
                    playlistIDs: playlistID.map { [$0] } ?? []
                )
            )
        }
    }

    public mutating func remove(trackID: String) {
        records.removeAll { $0.id == trackID }
    }

    public mutating func removeAll() {
        records.removeAll()
    }
}

public struct DownloadPlan: Equatable, Sendable {
    public var trackIDs: [String]

    public init(trackIDs: [String]) {
        self.trackIDs = trackIDs
    }
}

public enum DownloadPlanner {
    /// Remote HTTPS tracks that are not already in the cache. Bundled demos are skipped.
    public static func plan(trackIDs: [String], tracks: [Track], cache: OfflineCacheStore) -> DownloadPlan {
        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var planned: [String] = []
        for id in trackIDs {
            guard let track = lookup[id] else { continue }
            guard RemoteAudio.downloadURL(for: track) != nil else { continue }
            if cache.contains(track.id) { continue }
            if planned.contains(track.id) { continue }
            planned.append(track.id)
        }
        return DownloadPlan(trackIDs: planned)
    }
}
