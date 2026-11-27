import Foundation

public struct NowPlayingSnapshot: Codable, Equatable, Sendable {
    public static let defaultsKey = "mf.nowPlaying"

    public var title: String
    public var subtitle: String
    public var isPlaying: Bool
    public var isGenerative: Bool
    public var trackID: String?
    public var presetID: String?
    public var deepLink: String
    public var updatedAt: Date

    public init(
        title: String,
        subtitle: String,
        isPlaying: Bool,
        isGenerative: Bool,
        trackID: String?,
        presetID: String?,
        deepLink: String,
        updatedAt: Date
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isPlaying = isPlaying
        self.isGenerative = isGenerative
        self.trackID = trackID
        self.presetID = presetID
        self.deepLink = deepLink
        self.updatedAt = updatedAt
    }

    public static func catalog(track: Track, isPlaying: Bool, now: Date = Date()) -> NowPlayingSnapshot {
        let link = PlayerDeepLink.play(trackID: track.id).url.absoluteString
        return NowPlayingSnapshot(
            title: track.title,
            subtitle: track.artist,
            isPlaying: isPlaying,
            isGenerative: false,
            trackID: track.id,
            presetID: nil,
            deepLink: link,
            updatedAt: now
        )
    }

    public static func generative(preset: GenerativePreset, isPlaying: Bool, now: Date = Date()) -> NowPlayingSnapshot {
        let link = PlayerDeepLink.generative(presetID: preset.rawValue).url.absoluteString
        return NowPlayingSnapshot(
            title: preset.displayName,
            subtitle: ArtistName.display,
            isPlaying: isPlaying,
            isGenerative: true,
            trackID: nil,
            presetID: preset.rawValue,
            deepLink: link,
            updatedAt: now
        )
    }

    public static func idle(now: Date = Date()) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: "Matthew Finley Music Player",
            subtitle: "Ready when you are",
            isPlaying: false,
            isGenerative: false,
            trackID: nil,
            presetID: nil,
            deepLink: "mfmusic://play/amber-room",
            updatedAt: now
        )
    }

    public static func encode(_ snapshot: NowPlayingSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> NowPlayingSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NowPlayingSnapshot.self, from: data)
    }
}

public enum AppGroup {
    public static let identifier = "group.com.matthewfinley.musicplayer"
}
