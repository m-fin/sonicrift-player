import Foundation

/// Sample rate and channel count for an `AVAudioEngine` graph.
///
/// Core Audio raises an Objective-C exception, which Swift `do/catch` does not stop, when a node is
/// connected at 0 Hz or at a rate other than the running hardware rate. An iPhone session is usually
/// 48 kHz, and it stays 0 until the session is activated.
public struct AudioFormatPlan: Equatable, Sendable {
    public var sampleRate: Double
    public var channelCount: Int

    public init(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    public static func make(hardwareSampleRate: Double, hardwareChannels: Int = 2) -> AudioFormatPlan {
        let rate: Double
        if hardwareSampleRate.isFinite, hardwareSampleRate >= 8_000, hardwareSampleRate <= 192_000 {
            rate = hardwareSampleRate
        } else {
            rate = 48_000
        }
        let channels = hardwareChannels == 1 ? 1 : 2
        return AudioFormatPlan(sampleRate: rate, channelCount: channels)
    }
}

/// Pixel size for a Now Playing image.
///
/// `UIGraphicsImageRenderer` raises `NSInvalidArgumentException` when either side is below 1.
/// Lock Screen and Control Center request that image, sometimes at `CGSize.zero`, on the same turn as Play.
public struct ArtworkPixelSize: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static func sanitize(width: Double, height: Double, fallback: Int = 600) -> ArtworkPixelSize {
        let safeFallback = min(4096, max(1, fallback))
        guard width.isFinite, height.isFinite else {
            return ArtworkPixelSize(width: safeFallback, height: safeFallback)
        }
        let resolvedWidth = Int(width.rounded(.towardZero))
        let resolvedHeight = Int(height.rounded(.towardZero))
        guard resolvedWidth >= 1, resolvedHeight >= 1, resolvedWidth <= 4096, resolvedHeight <= 4096 else {
            return ArtworkPixelSize(width: safeFallback, height: safeFallback)
        }
        return ArtworkPixelSize(width: resolvedWidth, height: resolvedHeight)
    }
}

public enum AudioBufferLayout {
    /// Frames that fit in `mDataByteSize` for the buffer's channel count. Writing past that is a crash.
    public static func writableFrames(
        requestedFrames: Int,
        channelCount: Int,
        byteCount: Int,
        bytesPerSample: Int = MemoryLayout<Float>.size
    ) -> Int {
        guard requestedFrames > 0, channelCount > 0, byteCount > 0, bytesPerSample > 0 else { return 0 }
        let samples = byteCount / bytesPerSample
        return max(0, min(requestedFrames, samples / channelCount))
    }
}

public enum CatalogPlayability {
    public static func canStart(_ url: URL?) -> Bool {
        guard let url, !url.absoluteString.isEmpty else { return false }
        if url.isFileURL { return !url.path.isEmpty }
        switch url.scheme?.lowercased() {
        case "https", "http":
            return url.host != nil
        default:
            return false
        }
    }
}

/// Whether Play may message `AVAudioEngine`.
///
/// The engine reads the output format as soon as it is queried. Before `AVAudioSession.setActive(true)`
/// that format is 0 Hz, and Core Audio throws. A catalog play must not touch an engine that was never started.
public struct AudioEngineGate: Equatable, Sendable {
    public var sessionActive: Bool
    public var graphReady: Bool

    public init(sessionActive: Bool = false, graphReady: Bool = false) {
        self.sessionActive = sessionActive
        self.graphReady = graphReady
    }

    public var mayTouchEngine: Bool { sessionActive && graphReady }

    public enum Command: Equatable, Sendable {
        case activateSession
        case playCatalog
        case playGenerative
        case pauseEngine
    }

    public func applying(_ command: Command) -> (gate: AudioEngineGate, touchEngine: Bool) {
        var copy = self
        switch command {
        case .activateSession:
            copy.sessionActive = true
            return (copy, false)
        case .playCatalog, .pauseEngine:
            return (copy, copy.mayTouchEngine)
        case .playGenerative:
            guard copy.sessionActive else { return (copy, false) }
            copy.graphReady = true
            return (copy, true)
        }
    }
}
