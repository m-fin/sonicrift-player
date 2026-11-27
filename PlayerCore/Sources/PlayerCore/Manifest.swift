import Foundation

public struct ManifestFile: Equatable, Sendable {
    public var schema: String
    public var note: String?
    public var tracks: [Track]

    public init(schema: String, note: String?, tracks: [Track]) {
        self.schema = schema
        self.note = note
        self.tracks = tracks
    }
}

public enum ManifestParser {
    public static let currentSchema = "matthewfinley.tracks/v1"
    /// Accepted so documents written for the previous player still load.
    static let legacySchema = "sonicrift.tracks/v1"
    public static let defaultPermalink = "https://matthewfinley.org"

    public static func parse(_ data: Data) throws -> ManifestFile {
        let json = try JSONSerialization.jsonObject(with: data)
        return try parse(json: json)
    }

    public static func parse(json: Any) throws -> ManifestFile {
        guard let record = json as? [String: Any] else {
            throw ManifestError("Track manifest must be a JSON object.")
        }
        guard let schema = record["schema"] as? String, schema == currentSchema || schema == legacySchema else {
            throw ManifestError("Unsupported track manifest schema.")
        }
        guard let rawTracks = record["tracks"] as? [Any] else {
            throw ManifestError("Track manifest is missing tracks.")
        }
        let tracks = try rawTracks.enumerated().map { index, entry in
            guard let track = entry as? [String: Any] else {
                throw ManifestError("Track \(index) is not an object.")
            }
            guard let id = track["id"] as? String, !id.isEmpty, let title = track["title"] as? String, !title.isEmpty else {
                throw ManifestError("Track \(index) needs an id and a title.")
            }
            guard let placeholder = track["placeholder"] as? Bool else {
                throw ManifestError("Track \(id) must set placeholder to true or false.")
            }
            let artist = ArtistName.normalize(track["artist"] as? String)
            let album = nonEmpty(track["album"] as? String)
            let audioURL = track["audioUrl"] as? String
            let soundCloudURL = track["soundcloudUrl"] as? String
            let permalink = nonEmpty(track["permalink"] as? String) ?? soundCloudURL ?? defaultPermalink
            return Track(
                id: id,
                title: title,
                artist: artist,
                album: album,
                permalink: permalink,
                details: track["note"] as? String ?? track["description"] as? String,
                artworkURL: nonEmpty(track["artworkUrl"] as? String),
                releasedAt: parseDate(track["releasedAt"] as? String),
                durationMs: parseInt(track["durationMs"]),
                sourceID: "manifest",
                placeholder: placeholder,
                newDrop: (track["newDrop"] as? Bool) ?? false,
                playback: playback(audioURL: audioURL, soundCloudURL: soundCloudURL, permalink: permalink),
                moods: parseMoods(track["moods"])
            )
        }
        return ManifestFile(schema: schema, note: record["note"] as? String, tracks: tracks)
    }

    static func playback(audioURL: String?, soundCloudURL: String?, permalink: String) -> TrackPlayback {
        if let audioURL, audioURL.hasPrefix("bundled:") {
            let key = String(audioURL.dropFirst("bundled:".count))
            return .bundled(assetKey: key)
        }
        if let audioURL, audioURL.hasPrefix("https://") || audioURL.hasPrefix("http://") {
            return .remote(url: audioURL)
        }
        if let soundCloudURL, !soundCloudURL.isEmpty {
            return .page(url: soundCloudURL)
        }
        return .page(url: permalink)
    }

    private static func parseMoods(_ value: Any?) -> [Mood] {
        guard let names = value as? [String] else { return [] }
        var moods: [Mood] = []
        for name in names {
            if let mood = Mood(rawValue: name), !moods.contains(mood) {
                moods.append(mood)
            }
        }
        return moods
    }

    private static func parseInt(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double, double.isFinite { return Int(double) }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

public struct ManifestError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}
