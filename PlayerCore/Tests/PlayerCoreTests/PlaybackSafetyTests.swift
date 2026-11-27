import XCTest
@testable import PlayerCore

final class PlaybackSafetyTests: XCTestCase {
    func testFormatPlanRejectsAZeroOrInvalidHardwareRate() {
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: 0).sampleRate, 48_000)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: .nan).sampleRate, 48_000)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: -1).sampleRate, 48_000)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: .infinity).sampleRate, 48_000)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: 48_000).sampleRate, 48_000)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: 44_100).sampleRate, 44_100)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: 48_000, hardwareChannels: 1).channelCount, 1)
        XCTAssertEqual(AudioFormatPlan.make(hardwareSampleRate: 48_000, hardwareChannels: 0).channelCount, 2)
    }

    func testArtworkSizeIsNeverZero() {
        XCTAssertEqual(ArtworkPixelSize.sanitize(width: 0, height: 0), ArtworkPixelSize(width: 600, height: 600))
        XCTAssertEqual(ArtworkPixelSize.sanitize(width: -8, height: 64), ArtworkPixelSize(width: 600, height: 600))
        XCTAssertEqual(ArtworkPixelSize.sanitize(width: .nan, height: 10), ArtworkPixelSize(width: 600, height: 600))
        XCTAssertEqual(ArtworkPixelSize.sanitize(width: 10_000, height: 10), ArtworkPixelSize(width: 600, height: 600))
        XCTAssertEqual(ArtworkPixelSize.sanitize(width: 128.9, height: 64.2), ArtworkPixelSize(width: 128, height: 64))
    }

    func testWritableFramesStayInsideTheBuffer() {
        XCTAssertEqual(AudioBufferLayout.writableFrames(requestedFrames: 0, channelCount: 2, byteCount: 100), 0)
        XCTAssertEqual(AudioBufferLayout.writableFrames(requestedFrames: 512, channelCount: 0, byteCount: 4096), 0)
        XCTAssertEqual(AudioBufferLayout.writableFrames(requestedFrames: 512, channelCount: 2, byteCount: 0), 0)
        XCTAssertEqual(
            AudioBufferLayout.writableFrames(requestedFrames: 512, channelCount: 2, byteCount: 512 * 2 * 4),
            512
        )
        XCTAssertEqual(AudioBufferLayout.writableFrames(requestedFrames: 512, channelCount: 2, byteCount: 8), 1)
        XCTAssertEqual(AudioBufferLayout.writableFrames(requestedFrames: 4, channelCount: 1, byteCount: 4), 1)
    }

    func testCatalogPlayDoesNotTouchAColdEngine() {
        let cold = AudioEngineGate()
        let firstPlay = cold.applying(.playCatalog)
        XCTAssertFalse(firstPlay.touchEngine)
        XCTAssertFalse(firstPlay.gate.graphReady)

        let awake = cold.applying(.activateSession).gate
        let catalog = awake.applying(.playCatalog)
        XCTAssertTrue(catalog.gate.sessionActive)
        XCTAssertFalse(catalog.touchEngine, "Catalog play must not query an engine that has never been started")

        let blocked = awake.applying(.playGenerative)
        XCTAssertTrue(blocked.touchEngine)
        XCTAssertTrue(blocked.gate.mayTouchEngine)

        let backToCatalog = blocked.gate.applying(.playCatalog)
        XCTAssertTrue(backToCatalog.touchEngine)
        let paused = backToCatalog.gate.applying(.pauseEngine)
        XCTAssertTrue(paused.touchEngine)
    }

    func testGenerativePlayRefusesToBuildTheGraphBeforeTheSessionIsActive() {
        let cold = AudioEngineGate()
        let tooSoon = cold.applying(.playGenerative)
        XCTAssertFalse(tooSoon.touchEngine)
        XCTAssertFalse(tooSoon.gate.graphReady)
        XCTAssertFalse(tooSoon.gate.mayTouchEngine)
    }

    func testCatalogURLMustBeAFileOrHTTPResource() {
        XCTAssertFalse(CatalogPlayability.canStart(nil))
        XCTAssertFalse(CatalogPlayability.canStart(URL(string: "")))
        XCTAssertFalse(CatalogPlayability.canStart(URL(string: "mfmusic://play/amber-room")))
        XCTAssertTrue(CatalogPlayability.canStart(URL(fileURLWithPath: "/tmp/amber-room.wav")))
        XCTAssertTrue(CatalogPlayability.canStart(URL(string: "https://example.com/amber-room.mp3")))
        XCTAssertFalse(CatalogPlayability.canStart(URL(string: "ftp://example.com/a.mp3")))
    }

    func testEmptyRenderDoesNotTrap() {
        var engine = GenerativeEngine(parameters: GenerativeParameters(preset: .deepFocus, seed: 2))
        let silent = engine.render(frameCount: 0, sampleRate: 0)
        XCTAssertTrue(silent.left.isEmpty)
        XCTAssertEqual(silent.energy, .silent)

        var left: [Float] = []
        var right: [Float] = []
        var bass: [Float] = []
        let energy = engine.render(frameCount: 256, sampleRate: .nan, left: &left, right: &right, bass: &bass)
        XCTAssertEqual(energy, .silent)

        let finite = engine.render(frameCount: 64, sampleRate: 48_000)
        XCTAssertTrue(finite.left.allSatisfy(\.isFinite))
        XCTAssertEqual(finite.left.count, 64)
    }
}
