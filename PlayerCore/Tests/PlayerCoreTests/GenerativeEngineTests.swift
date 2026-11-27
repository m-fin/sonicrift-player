import XCTest
@testable import PlayerCore

final class GenerativeEngineTests: XCTestCase {
    func testEveryPresetKeepsBassPartialsUnder120Hz() {
        XCTAssertGreaterThanOrEqual(GenerativePreset.allCases.count, 5)
        for preset in GenerativePreset.allCases {
            let partials = GenerativePatch.bassPartials(for: preset)
            XCTAssertFalse(partials.isEmpty, preset.displayName)
            for frequency in partials {
                XCTAssertGreaterThan(frequency, 20, preset.displayName)
                XCTAssertLessThan(frequency, 120, "\(preset.displayName) partial \(frequency)")
            }
            let patch = GenerativePatch.make(preset: preset, seed: 7)
            XCTAssertTrue(patch.bassStaysBelow120Hz)
            XCTAssertFalse(patch.chords.isEmpty)
            for tone in patch.chords.flatMap({ $0 }) {
                XCTAssertGreaterThan(tone.leftHz, 140)
                XCTAssertGreaterThan(tone.rightHz, 140)
            }
        }
    }

    func testBassRenderIsFiniteMonoAndConcentratedBelow120Hz() {
        var engine = GenerativeEngine(parameters: GenerativeParameters(preset: .deepFocus, seed: 4, density: 0.4, warmth: 0.8))
        let buffer = engine.render(frameCount: 8820, sampleRate: 44_100, mode: .bassOnly)
        assertMusical(buffer.left)
        for index in buffer.left.indices {
            XCTAssertEqual(buffer.left[index], buffer.right[index], accuracy: 0.000_001)
            XCTAssertEqual(buffer.left[index], buffer.bass[index], accuracy: 0.000_001)
        }
        let below = SpectrumMath.bandPower(buffer.bass, sampleRate: 44_100, minHz: 20, maxHz: 115)
        let above = SpectrumMath.bandPower(buffer.bass, sampleRate: 44_100, minHz: 125, maxHz: 600)
        let fundamental = SpectrumMath.goertzelPower(buffer.bass, frequency: 55, sampleRate: 44_100)
        XCTAssertGreaterThan(below, 0)
        XCTAssertGreaterThan(fundamental, below * 0.2)
        XCTAssertLessThan(above, below * 0.02)
    }

    func testFullMixStaysBoundedAndKeepsLowEndMono() {
        var engine = GenerativeEngine(parameters: GenerativeParameters(preset: .warmDrift, seed: 11, density: 0.8, warmth: 0.9, tempo: 70, drift: 0.4))
        _ = engine.render(frameCount: 4_000, sampleRate: 44_100)
        let buffer = engine.render(frameCount: 8_820, sampleRate: 44_100)
        assertMusical(buffer.left)
        assertMusical(buffer.right)
        var side = [Float](repeating: 0, count: buffer.left.count)
        var mid = [Float](repeating: 0, count: buffer.left.count)
        for index in buffer.left.indices {
            side[index] = buffer.left[index] - buffer.right[index]
            mid[index] = (buffer.left[index] + buffer.right[index]) * 0.5
            XCTAssertEqual(mid[index] - buffer.bass[index], (buffer.left[index] + buffer.right[index]) * 0.5 - buffer.bass[index], accuracy: 0.000_1)
        }
        let sideLow = SpectrumMath.bandPower(side, sampleRate: 44_100, minHz: 20, maxHz: 115)
        let midLow = SpectrumMath.bandPower(mid, sampleRate: 44_100, minHz: 20, maxHz: 115)
        XCTAssertGreaterThan(midLow, 0)
        XCTAssertLessThan(sideLow, midLow * 0.05)
        XCTAssertGreaterThan(buffer.energy.low, 0)
    }

    func testEachPresetRendersAudibleFiniteAudio() {
        for preset in GenerativePreset.allCases {
            var engine = GenerativeEngine(parameters: GenerativeParameters(preset: preset, seed: 3, density: 0.6, warmth: 0.7))
            let buffer = engine.render(frameCount: 4_096, sampleRate: 48_000)
            assertMusical(buffer.left, label: preset.displayName)
            assertMusical(buffer.right, label: preset.displayName)
        }
    }

    func testANewSeedChangesTheBuffer() {
        var first = GenerativeEngine(parameters: GenerativeParameters(preset: .microtonalBloom, seed: 1, density: 0.7, warmth: 0.5))
        var second = GenerativeEngine(parameters: GenerativeParameters(preset: .microtonalBloom, seed: 99, density: 0.7, warmth: 0.5))
        let left = first.render(frameCount: 3_000, sampleRate: 44_100).left
        let right = second.render(frameCount: 3_000, sampleRate: 44_100).left
        let difference = zip(left, right).reduce(0.0) { $0 + abs(Double($1.0 - $1.1)) }
        XCTAssertGreaterThan(difference, 1)
        let next = SeedSource.next(after: 1)
        XCTAssertNotEqual(next, 1)
        XCTAssertNotEqual(SeedSource.next(after: 1), 0)
    }

    func testSwitchingRoutesNeverLeavesBothActive() {
        var session = PlaybackSession()
        session.playCatalog(trackID: "amber-room")
        XCTAssertEqual(session.route, .catalog)
        XCTAssertTrue(session.isPlaying)
        XCTAssertEqual(session.trackID, "amber-room")
        session.playGenerative(preset: .nightDrive, seed: 5)
        XCTAssertEqual(session.route, .generative)
        XCTAssertEqual(session.preset, .nightDrive)
        XCTAssertNotEqual(session.route, .catalog)
        session.setPlaying(false)
        XCTAssertFalse(session.isPlaying)
        XCTAssertEqual(session.route, .generative)
        session.playCatalog(trackID: "gold-hour")
        XCTAssertEqual(session.route, .catalog)
        XCTAssertNotEqual(session.route, .generative)
        session.stop()
        XCTAssertEqual(session.route, .idle)
        XCTAssertFalse(session.isPlaying)
    }

    func testDeepLinksRoundTrip() throws {
        let play = PlayerDeepLink.play(trackID: "soundcloud:tag/1")
        let parsed = try XCTUnwrap(PlayerDeepLink(url: play.url))
        XCTAssertEqual(parsed, play)
        XCTAssertTrue(play.url.absoluteString.hasPrefix("mfmusic://play/"))
        let generative = PlayerDeepLink.generative(presetID: GenerativePreset.sleepHalo.rawValue)
        XCTAssertEqual(PlayerDeepLink(url: generative.url), generative)
        XCTAssertNil(PlayerDeepLink(url: URL(string: "https://matthewfinley.org")!))
    }

    func testSnapshotRoundTrip() throws {
        let track = makeTrack(id: "amber-room", title: "Amber Room")
        let snapshot = NowPlayingSnapshot.catalog(track: track, isPlaying: true, now: Date(timeIntervalSince1970: 1_763_000_000))
        let decoded = try NowPlayingSnapshot.decode(try NowPlayingSnapshot.encode(snapshot))
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.title, "Amber Room")
        XCTAssertTrue(decoded.deepLink.hasPrefix("mfmusic://play/"))
        let mood = NowPlayingSnapshot.generative(preset: .deepFocus, isPlaying: true, now: Date(timeIntervalSince1970: 1_763_000_000))
        XCTAssertTrue(mood.deepLink.contains("mfmusic://generative/deep-focus"))
        XCTAssertEqual(mood.subtitle, "Matthew Finley")
    }

    private func assertMusical(_ samples: [Float], label: String = "buffer") {
        XCTAssertFalse(samples.isEmpty, label)
        XCTAssertTrue(samples.allSatisfy(\.isFinite), label)
        let peak = samples.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(peak, 1, label)
        XCTAssertGreaterThan(peak, 0.02, label)
        let energy = samples.reduce(0.0) { $0 + Double($1 * $1) }
        let rms = (energy / Double(samples.count)).squareRoot()
        XCTAssertGreaterThan(rms, 0.02, label)
    }
}
