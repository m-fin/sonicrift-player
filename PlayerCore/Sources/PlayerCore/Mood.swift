import Foundation

public enum Mood: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case focus = "Focus"
    case lateNight = "Late Night"
    case sleep = "Sleep"
    case ambient = "Ambient"
    case driving = "Driving"
    case electronic = "Electronic"

    public var id: String { rawValue }

    public var blurb: String {
        switch self {
        case .focus: return "Steady pieces for a long stretch of work."
        case .lateNight: return "Dim, slow, and a little gold around the edges."
        case .sleep: return "Quiet enough to leave running."
        case .ambient: return "Wide pads and plenty of air."
        case .driving: return "Motion, low end, and a horizon."
        case .electronic: return "Sequences, pulses, and code-shaped rhythm."
        }
    }

    public static func infer(title: String, details: String?) -> [Mood] {
        let text = (title + " " + (details ?? "")).lowercased()
        var found: [Mood] = []
        func hit(_ mood: Mood, _ words: [String]) {
            if words.contains(where: { text.contains($0) }) {
                found.append(mood)
            }
        }
        hit(.focus, ["focus", "deep", "study"])
        hit(.lateNight, ["late night", "late-night", "midnight", "after dark"])
        hit(.sleep, ["sleep", "rest", "lullaby"])
        hit(.ambient, ["ambient", "drift", "space", "pad"])
        hit(.driving, ["drive", "driving", "highway", "night drive"])
        hit(.electronic, ["electronic", "bionic", "machine", "sequence", "synth"])
        return found
    }
}
