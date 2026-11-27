import Foundation

public enum AudioRoute: Equatable, Sendable {
    case idle
    case catalog
    case generative
}

/// One active route. Starting catalog playback leaves generative silence, and the reverse.
public struct PlaybackSession: Equatable, Sendable {
    public var route: AudioRoute
    public var isPlaying: Bool
    public var trackID: String?
    public var preset: GenerativePreset?
    public var seed: UInt64

    public init(
        route: AudioRoute = .idle,
        isPlaying: Bool = false,
        trackID: String? = nil,
        preset: GenerativePreset? = nil,
        seed: UInt64 = 1
    ) {
        self.route = route
        self.isPlaying = isPlaying
        self.trackID = trackID
        self.preset = preset
        self.seed = seed == 0 ? 1 : seed
    }

    public mutating func playCatalog(trackID: String) {
        route = .catalog
        isPlaying = true
        self.trackID = trackID
    }

    public mutating func playGenerative(preset: GenerativePreset, seed: UInt64) {
        route = .generative
        isPlaying = true
        self.preset = preset
        self.seed = seed == 0 ? 1 : seed
    }

    public mutating func setPlaying(_ playing: Bool) {
        guard route != .idle else {
            isPlaying = false
            return
        }
        isPlaying = playing
    }

    public mutating func stop() {
        route = .idle
        isPlaying = false
    }
}
