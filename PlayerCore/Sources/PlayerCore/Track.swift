import Foundation

public enum TrackPlayback: Equatable, Sendable {
    case remote(url: String)
    case bundled(assetKey: String)
    case page(url: String)
}

public struct Track: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String?
    public var permalink: String
    public var details: String?
    public var artworkURL: String?
    public var releasedAt: Date?
    public var durationMs: Int?
    public var sourceID: String
    public var placeholder: Bool
    public var newDrop: Bool
    public var playback: TrackPlayback
    public var moods: [Mood]

    public init(
        id: String,
        title: String,
        artist: String = ArtistName.display,
        album: String? = nil,
        permalink: String,
        details: String? = nil,
        artworkURL: String? = nil,
        releasedAt: Date? = nil,
        durationMs: Int? = nil,
        sourceID: String,
        placeholder: Bool,
        newDrop: Bool = false,
        playback: TrackPlayback,
        moods: [Mood] = []
    ) {
        self.id = id
        self.title = title
        self.artist = ArtistName.normalize(artist)
        self.album = album
        self.permalink = permalink
        self.details = details
        self.artworkURL = artworkURL
        self.releasedAt = releasedAt
        self.durationMs = durationMs
        self.sourceID = sourceID
        self.placeholder = placeholder
        self.newDrop = newDrop
        self.playback = playback
        self.moods = moods
    }

    public func resolvedMoods() -> [Mood] {
        moods.isEmpty ? Mood.infer(title: title, details: details) : moods
    }

    public var isBundled: Bool {
        if case .bundled = playback { return true }
        return false
    }
}

public enum RemoteAudio {
    public static func downloadURL(for track: Track) -> URL? {
        guard case let .remote(raw) = track.playback else { return nil }
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
