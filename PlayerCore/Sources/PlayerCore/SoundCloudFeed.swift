import Foundation

public struct RSSTrack: Equatable, Sendable {
    public var id: String
    public var title: String
    public var details: String
    public var permalink: String
    public var streamURL: String
    public var artworkURL: String?
    public var releasedAt: Date?
    public var durationMs: Int?

    public init(
        id: String,
        title: String,
        details: String,
        permalink: String,
        streamURL: String,
        artworkURL: String? = nil,
        releasedAt: Date? = nil,
        durationMs: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.permalink = permalink
        self.streamURL = streamURL
        self.artworkURL = artworkURL
        self.releasedAt = releasedAt
        self.durationMs = durationMs
    }
}

public struct OEmbedProfile: Equatable, Sendable {
    public var title: String?
    public var authorName: String?
    public var authorURL: String?
    public var thumbnailURL: String?
    public var html: String?
    public var details: String?

    public init(
        title: String? = nil,
        authorName: String? = nil,
        authorURL: String? = nil,
        thumbnailURL: String? = nil,
        html: String? = nil,
        details: String? = nil
    ) {
        self.title = title
        self.authorName = authorName
        self.authorURL = authorURL
        self.thumbnailURL = thumbnailURL
        self.html = html
        self.details = details
    }
}

public enum SoundCloudFeed {
    public static func parseRSS(_ xml: String) -> [RSSTrack] {
        guard let expression = try? NSRegularExpression(pattern: #"<item\b[^>]*>([\s\S]*?)</item>"#, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(xml.startIndex..., in: xml)
        return expression.matches(in: xml, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let blockRange = Range(match.range(at: 1), in: xml) else { return nil }
            let block = String(xml[blockRange])
            let title = tagText(block, tag: "title")
            let permalink = tagText(block, tag: "link")
            guard let streamURL = attribute(block, tag: "enclosure", name: "url"),
                  !title.isEmpty, !permalink.isEmpty else { return nil }
            let guid = tagText(block, tag: "guid")
            let published = tagText(block, tag: "pubDate")
            let summary = tagText(block, tag: "description")
            let itunes = tagText(block, tag: "itunes:summary")
            return RSSTrack(
                id: guid.isEmpty ? permalink : guid,
                title: title,
                details: summary.isEmpty ? itunes : summary,
                permalink: permalink,
                streamURL: streamURL,
                artworkURL: attribute(block, tag: "itunes:image", name: "href"),
                releasedAt: parseRSSDate(published),
                durationMs: parseDuration(tagText(block, tag: "itunes:duration"))
            )
        }
    }

    public static func nextPage(in xml: String) -> String? {
        guard let link = firstMatch(xml, pattern: #"<atom:link\b[^>]*rel=["']next["'][^>]*>"#) else { return nil }
        return attributeValue(link, name: "href")
    }

    public static func userID(fromWidgetHTML html: String) -> String? {
        if let encoded = firstGroup(html, pattern: #"api\.soundcloud\.com%2Fusers%2F(\d+)"#) {
            return encoded
        }
        return firstGroup(html, pattern: #"api\.soundcloud\.com/users/(\d+)"#)
    }

    public static func rssURL(forUserID userID: String) -> URL? {
        URL(string: "https://feeds.soundcloud.com/users/soundcloud:users:\(userID)/sounds.rss")
    }

    public static func readOEmbed(_ value: Any) -> OEmbedProfile {
        guard let record = value as? [String: Any] else { return OEmbedProfile() }
        func pick(_ key: String) -> String? { record[key] as? String }
        return OEmbedProfile(
            title: pick("title"),
            authorName: pick("author_name"),
            authorURL: pick("author_url"),
            thumbnailURL: pick("thumbnail_url"),
            html: pick("html"),
            details: pick("description")
        )
    }

    public static func tracks(from items: [RSSTrack]) -> [Track] {
        items.compactMap { item in
            guard !ThirdPartyFilter.isThirdParty(title: item.title, details: item.details) else { return nil }
            return Track(
                id: "soundcloud:\(item.id)",
                title: item.title,
                artist: ArtistName.display,
                permalink: item.permalink,
                details: item.details,
                artworkURL: item.artworkURL,
                releasedAt: item.releasedAt,
                durationMs: item.durationMs,
                sourceID: "soundcloud-rss",
                placeholder: false,
                playback: .remote(url: item.streamURL)
            )
        }
    }

    public static func parseDuration(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let parts = trimmed.split(separator: ":").map { Int($0) }
        if parts.contains(where: { $0 == nil }) { return nil }
        let numbers = parts.compactMap { $0 }
        let seconds: Int
        switch numbers.count {
        case 3: seconds = numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        case 2: seconds = numbers[0] * 60 + numbers[1]
        case 1: seconds = numbers[0]
        default: return nil
        }
        return seconds * 1000
    }

    static func parseRSSDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: trimmed)
    }

    private static func tagText(_ block: String, tag: String) -> String {
        let pattern = "<\(NSRegularExpression.escapedPattern(for: tag))\\b[^>]*>([\\s\\S]*?)</\(NSRegularExpression.escapedPattern(for: tag))>"
        guard let raw = firstGroup(block, pattern: pattern) else { return "" }
        return decode(raw)
    }

    private static func attribute(_ block: String, tag: String, name: String) -> String? {
        let pattern = "<\(NSRegularExpression.escapedPattern(for: tag))\\b[^>]*>"
        guard let opening = firstMatch(block, pattern: pattern) else { return nil }
        return attributeValue(opening, name: name)
    }

    private static func attributeValue(_ opening: String, name: String) -> String? {
        let pattern = "\(NSRegularExpression.escapedPattern(for: name))=[\"']([^\"']+)[\"']"
        guard let value = firstGroup(opening, pattern: pattern) else { return nil }
        return decode(value)
    }

    private static func decode(_ value: String) -> String {
        var text = value
        if let cdata = firstGroup(text, pattern: #"<!\[CDATA\[([\s\S]*?)\]\]>"#) {
            text = cdata
        }
        let replacements = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
        ]
        for (escaped, plain) in replacements {
            text = text.replacingOccurrences(of: escaped, with: plain)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(_ text: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range), let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    private static func firstGroup(_ text: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }
}
