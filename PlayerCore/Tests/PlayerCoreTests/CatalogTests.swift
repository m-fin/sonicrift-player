import XCTest
@testable import PlayerCore

final class CatalogTests: XCTestCase {
    func testCurrentSchemaParsesMoodsAlbumAndBundledAudio() throws {
        let json = """
        {
          "schema": "matthewfinley.tracks/v1",
          "note": "Original synthesized demos.",
          "tracks": [
            {
              "id": "amber-room",
              "title": "Amber Room",
              "artist": "Matthew Finley",
              "album": "Studio Demos",
              "placeholder": true,
              "moods": ["Focus", "Ambient", "Not A Mood"],
              "audioUrl": "bundled:amber-room",
              "permalink": "https://matthewfinley.org",
              "releasedAt": "2026-11-01T00:00:00Z",
              "durationMs": 12000
            }
          ]
        }
        """.data(using: .utf8)!
        let manifest = try ManifestParser.parse(json)
        XCTAssertEqual(manifest.schema, ManifestParser.currentSchema)
        XCTAssertEqual(manifest.tracks.count, 1)
        let track = try XCTUnwrap(manifest.tracks.first)
        XCTAssertEqual(track.artist, "Matthew Finley")
        XCTAssertEqual(track.album, "Studio Demos")
        XCTAssertEqual(track.moods, [.focus, .ambient])
        XCTAssertEqual(track.playback, .bundled(assetKey: "amber-room"))
        XCTAssertEqual(track.durationMs, 12000)
        XCTAssertEqual(track.placeholder, true)
    }

    func testLegacySchemaNormalizesTheHistoricalCredit() throws {
        let json = """
        {
          "schema": "sonicrift.tracks/v1",
          "tracks": [
            {"id": "bionic", "title": "Bionic Body", "artist": "sonicrift", "placeholder": false, "audioUrl": "https://example.com/bionic.mp3"}
          ]
        }
        """.data(using: .utf8)!
        let manifest = try ManifestParser.parse(json)
        XCTAssertEqual(manifest.tracks.first?.artist, "Matthew Finley")
        XCTAssertEqual(manifest.tracks.first?.playback, .remote(url: "https://example.com/bionic.mp3"))
    }

    func testManifestRejectsAMissingPlaceholderFlag() {
        let json = """
        {"schema":"matthewfinley.tracks/v1","tracks":[{"id":"x","title":"x"}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try ManifestParser.parse(json)) { error in
            XCTAssertTrue(String(describing: error).contains("placeholder"))
        }
    }

    func testManifestRejectsAnUnknownSchema() {
        let json = #"{"schema":"other.tracks/v1","tracks":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try ManifestParser.parse(json))
    }

    func testMergePrefersReleasedTracksAndDropsDuplicatePermalinks() {
        let released = makeTrack(
            id: "soundcloud:1",
            title: "Bionic Body",
            permalink: "https://soundcloud.com/example/bionic-body",
            releasedAt: date("2026-11-01T00:00:00Z")
        )
        let duplicate = makeTrack(
            id: "dup",
            title: "Bionic Body duplicate",
            permalink: "https://soundcloud.com/example/bionic-body"
        )
        let demo = makeTrack(id: "demo", title: "Amber Room", placeholder: true, playback: .bundled(assetKey: "amber-room"))
        let merged = CatalogMerger.merge([[released], [demo], [duplicate]])
        XCTAssertEqual(merged.map(\.title), ["Bionic Body", "Amber Room"])
        XCTAssertEqual(merged.last?.placeholder, true)
    }

    func testNewDropIsTheRecentNonPlaceholderRelease() {
        let now = date("2026-11-14T00:00:00Z")
        let tracks = [
            makeTrack(id: "old", title: "Old", releasedAt: date("2026-09-01T00:00:00Z")),
            makeTrack(id: "bionic", title: "Bionic Body", releasedAt: date("2026-11-01T21:17:25Z")),
            makeTrack(id: "tone", title: "Tone", placeholder: true, newDrop: true, releasedAt: date("2026-11-13T00:00:00Z")),
            makeTrack(id: "flagged", title: "Flagged", newDrop: true, releasedAt: date("2026-01-01T00:00:00Z")),
        ]
        XCTAssertEqual(NewDrops.select(tracks: tracks, now: now), ["bionic", "flagged"])
    }

    func testSoundCloudPagesDropThirdPartyAndBuildMatthewFinleyTracks() throws {
        let items = SoundCloudFeed.parseRSS(rssFixture)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Bionic Body")
        XCTAssertEqual(items[0].durationMs, 108_000)
        XCTAssertEqual(items[0].artworkURL, "https://i1.sndcdn.com/artworks-example.jpg")
        XCTAssertEqual(items[0].releasedAt, date("2026-11-01T21:17:25Z"))
        XCTAssertEqual(
            SoundCloudFeed.nextPage(in: rssFixture),
            "https://feeds.soundcloud.com/users/soundcloud:users:1/sounds.rss?before=9"
        )
        let playable = SoundCloudFeed.tracks(from: items)
        XCTAssertEqual(playable.map(\.title), ["Bionic Body"])
        XCTAssertEqual(playable.first?.artist, "Matthew Finley")
        XCTAssertFalse(playable.contains { track in
            if case let .remote(url) = track.playback { return url.contains("third-party") }
            return false
        })
    }

    func testWidgetHTMLYieldsThePublicRSSURL() throws {
        let html = #"<iframe src="https://w.soundcloud.com/player/?visual=true&url=https%3A%2F%2Fapi.soundcloud.com%2Fusers%2F106237603&show_artwork=true"></iframe>"#
        let userID = try XCTUnwrap(SoundCloudFeed.userID(fromWidgetHTML: html))
        XCTAssertEqual(userID, "106237603")
        XCTAssertEqual(
            SoundCloudFeed.rssURL(forUserID: userID)?.absoluteString,
            "https://feeds.soundcloud.com/users/soundcloud:users:106237603/sounds.rss"
        )
    }

    func testSnapshotDropsThirdPartyAndKeepsOriginals() throws {
        let json = """
        {
          "capturedAt": "2026-11-14",
          "tracks": [
            {
              "id": "100",
              "title": "Space Drift",
              "description": "Made entirely with code.",
              "permalink": "https://soundcloud.com/example/space-drift",
              "streamUrl": "https://feeds.soundcloud.com/stream/space.mp3",
              "releasedAt": "2026-10-13T11:04:41.000Z",
              "durationMs": 600000
            },
            {
              "id": "stolen",
              "title": "Someone Else - Stolen Loop",
              "description": "no copyright infringement intended",
              "permalink": "https://soundcloud.com/example/stolen",
              "streamUrl": "https://feeds.soundcloud.com/stream/stolen.mp3"
            }
          ]
        }
        """.data(using: .utf8)!
        let snapshot = try SoundCloudSnapshot.parse(json)
        XCTAssertEqual(snapshot.tracks.map(\.title), ["Space Drift"])
        XCTAssertEqual(snapshot.tracks.first?.artist, "Matthew Finley")
    }
}

final class ThirdPartyFilterTests: XCTestCase {
    func testKeepsOriginalsAndRejectsCreditedThirdPartyAudio() {
        XCTAssertFalse(ThirdPartyFilter.isThirdParty(title: "Bionic Body", details: "Made entirely with code in Python."))
        XCTAssertFalse(ThirdPartyFilter.isThirdParty(title: "Machine Sleep"))
        XCTAssertFalse(ThirdPartyFilter.isThirdParty(title: "sonicrift - night loop"))
        XCTAssertFalse(ThirdPartyFilter.isThirdParty(title: "Matthew Finley - Amber Room"))
        XCTAssertTrue(
            ThirdPartyFilter.isThirdParty(
                title: "Yeat - Real Geek (prod. Ice Cream) [Slowed Instrumental]",
                details: "Clean slowed instrumental. All rights to the original artists, no copyright infringement intended."
            )
        )
        XCTAssertTrue(
            ThirdPartyFilter.isThirdParty(
                title: "Night Drive",
                details: "A slowed instrumental of \"Real Geek\". No copyright infringement intended."
            )
        )
        XCTAssertTrue(ThirdPartyFilter.isThirdParty(title: "Someone Else - Stolen Loop"))
    }
}

func makeTrack(
    id: String,
    title: String,
    permalink: String? = nil,
    placeholder: Bool = false,
    newDrop: Bool = false,
    playback: TrackPlayback = .remote(url: "https://example.com/a.mp3"),
    releasedAt: Date? = nil,
    album: String? = nil,
    moods: [Mood] = [],
    details: String? = nil
) -> Track {
    Track(
        id: id,
        title: title,
        album: album,
        permalink: permalink ?? "https://matthewfinley.org/\(id)",
        details: details,
        releasedAt: releasedAt,
        sourceID: "test",
        placeholder: placeholder,
        newDrop: newDrop,
        playback: playback,
        moods: moods
    )
}

func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
}

let rssFixture = """
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <atom:link href="https://feeds.soundcloud.com/users/soundcloud:users:1/sounds.rss?before=9" rel="next" type="application/rss+xml"/>
    <item>
      <title>Bionic Body</title>
      <link>https://soundcloud.com/example/bionic-body</link>
      <pubDate>Sun, 01 Nov 2026 21:17:25 +0000</pubDate>
      <guid>tag:soundcloud,2010:tracks/100</guid>
      <description>Made entirely with code.</description>
      <enclosure type="audio/mpeg" url="https://feeds.soundcloud.com/stream/100-bionic-body.mp3" length="10"/>
      <itunes:duration>00:01:48</itunes:duration>
      <itunes:image href="https://i1.sndcdn.com/artworks-example.jpg"/>
    </item>
    <item>
      <title>Yeat - Real Geek (prod. Ice Cream) [Slowed Instrumental]</title>
      <link>https://soundcloud.com/example/yeat-real-geek</link>
      <description>No copyright infringement intended.</description>
      <enclosure url="https://feeds.soundcloud.com/stream/secret-third-party.mp3" type="audio/mpeg"/>
    </item>
  </channel>
</rss>
"""
