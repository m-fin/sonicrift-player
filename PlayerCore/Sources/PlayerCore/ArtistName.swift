import Foundation

public enum ArtistName {
    public static let display = "Matthew Finley"

    /// Maps an empty credit, or the historical project credit, to the public artist name.
    public static func normalize(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return display }
        if trimmed.compare(legacyProjectCredit, options: .caseInsensitive) == .orderedSame {
            return display
        }
        return trimmed
    }

    /// Historical catalog credit. Compared internally so older manifests display the public name.
    static let legacyProjectCredit = "sonicrift"
}
