import Foundation

public enum ThirdPartyFilter {
    /// Titles credited to another artist, and notes that say the audio belongs to someone else, are not queued.
    /// Originals are untitled pieces, or pieces credited to Matthew Finley or the historical catalog name.
    public static func isThirdParty(title: String, details: String? = nil) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if artistCreditPattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return true
        }
        if copyrightPattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return true
        }
        if let details, copyrightPattern.firstMatch(in: details, range: NSRange(details.startIndex..., in: details)) != nil {
            return true
        }
        return false
    }

    private static let artistCreditPattern: NSRegularExpression = {
        let pattern = #"^\s*(?!(?:sonicrift|matthew\s+finley)\b)[^:\n]{1,48}?\s[-–—]\s"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let copyrightPattern: NSRegularExpression = {
        let pattern = #"no copyright infringement|all rights to the original|slowed instrumental of|instrumental of ["“]|cover of|remix of"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
}
