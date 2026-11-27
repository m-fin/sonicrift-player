import XCTest
@testable import PlayerCore

final class LibraryAndOfflineTests: XCTestCase {
    func testMoodInferenceAndFiltering() {
        let machine = makeTrack(
            id: "sleep",
            title: "Machine Sleep",
            details: "Ten minutes of dim, resting-machine ambient for sleep or deep focus."
        )
        XCTAssertTrue(machine.resolvedMoods().contains(.sleep))
        XCTAssertTrue(machine.resolvedMoods().contains(.focus))
        XCTAssertTrue(machine.resolvedMoods().contains(.ambient))
        XCTAssertTrue(machine.resolvedMoods().contains(.electronic))

        let amber = makeTrack(id: "amber", title: "Amber Room", album: "Studio Demos", moods: [.focus, .ambient])
        let gold = makeTrack(id: "gold", title: "Gold Hour", album: "Studio Demos", moods: [.lateNight, .driving])
        let single = makeTrack(id: "single", title: "Loose Wire", moods: [.electronic])
        let tracks = [amber, gold, single, machine]
        XCTAssertEqual(LibraryBrowser.tracks(tracks, mood: .driving).map(\.id), ["gold"])
        XCTAssertEqual(LibraryBrowser.tracks(tracks, mood: .focus).map(\.id), ["amber", "sleep"])
    }

    func testAlbumsFavoritesAndLatestDrops() {
        let now = date("2026-11-14T00:00:00Z")
        let recent = makeTrack(id: "recent", title: "Recent", releasedAt: date("2026-11-10T00:00:00Z"), album: "Night")
        let demo = makeTrack(
            id: "demo",
            title: "Amber Room",
            placeholder: true,
            playback: .bundled(assetKey: "amber-room"),
            album: "Studio Demos",
            moods: [.focus]
        )
        let single = makeTrack(id: "single", title: "Loose Wire")
        let tracks = [demo, single, recent]
        XCTAssertEqual(LibraryBrowser.latestDrops(in: tracks, now: now).map(\.id), ["recent"])
        let albums = LibraryBrowser.albums(in: tracks)
        XCTAssertEqual(albums.map { $0.title }, ["Night", "Studio Demos", "Singles"])
        var favorites = FavoritesStore()
        favorites.toggle("demo")
        favorites.toggle("single")
        favorites.toggle("demo")
        XCTAssertEqual(favorites.ids, ["single"])
        favorites.toggle("recent")
        XCTAssertEqual(LibraryBrowser.favorites(tracks, store: favorites).map(\.id), ["single", "recent"])
    }

    func testOfflineCacheStorePathsAndPlaylistBytes() {
        var cache = OfflineCacheStore()
        let when = date("2026-11-20T00:00:00Z")
        cache.markDownloaded(trackID: "soundcloud:track/1", byteCount: 1_000, downloadedAt: when, playlistID: "mood:Focus")
        cache.markDownloaded(trackID: "soundcloud:track/2", byteCount: 2_500, downloadedAt: when, playlistID: "mood:Focus")
        cache.markDownloaded(trackID: "soundcloud:track/1", byteCount: 1_100, downloadedAt: when, playlistID: "album:Night")
        XCTAssertEqual(cache.records.count, 2)
        XCTAssertEqual(cache.totalBytes, 3_600)
        XCTAssertTrue(cache.contains("soundcloud:track/1"))
        XCTAssertEqual(cache.record(for: "soundcloud:track/1")?.playlistIDs, ["mood:Focus", "album:Night"])
        XCTAssertTrue(cache.record(for: "soundcloud:track/1")?.relativePath.hasPrefix("OfflineAudio/") == true)
        XCTAssertFalse(cache.record(for: "soundcloud:track/1")?.relativePath.contains("/") == false)
        XCTAssertEqual(cache.records(inPlaylist: "mood:Focus").count, 2)
        cache.remove(trackID: "soundcloud:track/2")
        XCTAssertEqual(cache.totalBytes, 1_100)
        cache.removeAll()
        XCTAssertEqual(cache.totalBytes, 0)
    }

    func testDownloadPlannerSkipsBundledAndCachedTracks() {
        let remote = makeTrack(id: "remote", title: "Space Drift")
        let insecure = makeTrack(id: "http", title: "Plain", playback: .remote(url: "http://example.com/a.mp3"))
        let bundled = makeTrack(id: "amber", title: "Amber Room", playback: .bundled(assetKey: "amber-room"))
        var cache = OfflineCacheStore()
        cache.markDownloaded(trackID: "remote", byteCount: 10, downloadedAt: date("2026-11-01T00:00:00Z"))
        let fresh = makeTrack(id: "fresh", title: "Fresh", playback: .remote(url: "https://cdn.example.com/fresh.mp3"))
        let plan = DownloadPlanner.plan(
            trackIDs: ["remote", "http", "amber", "fresh", "missing"],
            tracks: [remote, insecure, bundled, fresh],
            cache: cache
        )
        XCTAssertEqual(plan.trackIDs, ["fresh"])
    }

    func testOfflineFilterIncludesBundledAndDownloads() {
        let bundled = makeTrack(id: "amber", title: "Amber Room", playback: .bundled(assetKey: "amber-room"))
        let remote = makeTrack(id: "remote", title: "Space Drift")
        let saved = makeTrack(id: "saved", title: "Machine Sleep")
        var cache = OfflineCacheStore()
        cache.markDownloaded(trackID: "saved", byteCount: 20, downloadedAt: date("2026-11-02T00:00:00Z"))
        let tracks = [bundled, remote, saved]
        XCTAssertEqual(LibraryBrowser.onDevice(tracks, cache: cache).map(\.id), ["amber", "saved"])
        XCTAssertEqual(
            LibraryBrowser.applyingOfflineFilter(tracks, cache: cache, offlineOnly: true).map(\.id),
            ["amber", "saved"]
        )
        XCTAssertEqual(LibraryBrowser.applyingOfflineFilter(tracks, cache: cache, offlineOnly: false).count, 3)
        XCTAssertTrue(LibraryBrowser.isOnDevice(bundled, cache: OfflineCacheStore()))
    }

    func testRelativePathStaysInsideOfflineAudio() {
        let path = OfflineAudioLocation.relativePath(for: "soundcloud:tag/1")
        XCTAssertTrue(path.hasPrefix("\(OfflineAudioLocation.directoryName)/"))
        XCTAssertFalse(path.contains(".."))
        XCTAssertFalse(path.contains(":"))
        XCTAssertTrue(path.hasSuffix(".audio"))
    }
}
