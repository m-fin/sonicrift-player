import Foundation

public enum PlayerDeepLink: Equatable, Sendable {
    case play(trackID: String)
    case generative(presetID: String)

    public init?(url: URL) {
        guard url.scheme?.lowercased() == "mfmusic" else { return nil }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let decoded = path.removingPercentEncoding ?? path
        switch host {
        case "play":
            guard !decoded.isEmpty else { return nil }
            self = .play(trackID: decoded)
        case "generative":
            guard !decoded.isEmpty else { return nil }
            self = .generative(presetID: decoded)
        default:
            return nil
        }
    }

    public var url: URL {
        switch self {
        case let .play(trackID):
            let encoded = trackID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trackID
            return URL(string: "mfmusic://play/\(encoded)")!
        case let .generative(presetID):
            let encoded = presetID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? presetID
            return URL(string: "mfmusic://generative/\(encoded)")!
        }
    }
}
