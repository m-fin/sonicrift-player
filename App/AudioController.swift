import AVFoundation
import MediaPlayer
import PlayerCore
import UIKit

final class GenerativeRenderBox: @unchecked Sendable {
    private let lock = NSLock()
    private var engine: GenerativeEngine
    private var leftScratch: [Float] = []
    private var rightScratch: [Float] = []
    private var bassScratch: [Float] = []
    private(set) var energy = VisualEnergy.silent

    init(parameters: GenerativeParameters) {
        engine = GenerativeEngine(parameters: parameters)
    }

    func update(_ parameters: GenerativeParameters) {
        lock.lock()
        engine.update(parameters)
        lock.unlock()
    }

    func currentEnergy() -> VisualEnergy {
        lock.lock()
        defer { lock.unlock() }
        return energy
    }

    func render(frameCount: Int, sampleRate: Double, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        lock.lock()
        defer { lock.unlock() }
        if leftScratch.count < frameCount {
            leftScratch = [Float](repeating: 0, count: frameCount)
            rightScratch = [Float](repeating: 0, count: frameCount)
            bassScratch = [Float](repeating: 0, count: frameCount)
        }
        energy = engine.render(
            frameCount: frameCount,
            sampleRate: sampleRate,
            left: &leftScratch,
            right: &rightScratch,
            bass: &bassScratch
        )
        for index in 0..<frameCount {
            left[index] = leftScratch[index]
            right[index] = rightScratch[index]
        }
    }
}

@MainActor
final class AudioController: ObservableObject {
    weak var model: PlayerModel?
    private let player = AVPlayer()
    private let engine = AVAudioEngine()
    private let renderBox: GenerativeRenderBox
    private var sourceNode: AVAudioSourceNode?
    private var engineReady = false
    private var timeToken: Any?
    private var observers: [NSObjectProtocol] = []
    private var commandsInstalled = false
    private var generativeAnchor: Date?
    private var generativeElapsed: TimeInterval = 0
    private let sampleRate: Double = 44_100

    init() {
        renderBox = GenerativeRenderBox(parameters: GenerativeParameters(preset: .deepFocus))
    }

    func prepare() {
        installCommands()
        observePlayer()
    }

    func play(track: Track, url: URL) {
        pauseGenerativeEngine()
        generativeAnchor = nil
        generativeElapsed = 0
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        configureSession()
        player.play()
        publishCatalog(track: track, playing: true)
    }

    func playGenerative(_ parameters: GenerativeParameters) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        renderBox.update(parameters)
        configureSession()
        do {
            try ensureEngine()
            if !engine.isRunning {
                try engine.start()
            }
            generativeAnchor = Date()
            publishGenerative(parameters: parameters, playing: true)
        } catch {
            model?.statusMessage = "The generative engine didn't start."
        }
    }

    func updateGenerative(_ parameters: GenerativeParameters) {
        renderBox.update(parameters)
        if model?.session.route == .generative, model?.session.isPlaying == true {
            publishGenerative(parameters: parameters, playing: true)
        }
    }

    func pause() {
        if model?.session.route == .generative {
            captureGenerativeElapsed()
            engine.pause()
            if let parameters = model?.generative {
                publishGenerative(parameters: parameters, playing: false)
            }
        } else {
            player.pause()
            if let track = model?.currentTrack {
                publishCatalog(track: track, playing: false)
            }
        }
    }

    func resume() {
        configureSession()
        if model?.session.route == .generative {
            do {
                try ensureEngine()
                if !engine.isRunning { try engine.start() }
                generativeAnchor = Date()
                if let parameters = model?.generative {
                    publishGenerative(parameters: parameters, playing: true)
                }
            } catch {
                model?.statusMessage = "The generative engine didn't start."
            }
        } else {
            player.play()
            if let track = model?.currentTrack {
                publishCatalog(track: track, playing: true)
            }
        }
    }

    func seek(to seconds: Double) {
        guard model?.session.route == .catalog else { return }
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        if let track = model?.currentTrack {
            publishCatalog(track: track, playing: player.rate > 0)
        }
    }

    func stopAll() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        pauseGenerativeEngine()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func pollEnergy() -> VisualEnergy {
        renderBox.currentEnergy()
    }

    private func pauseGenerativeEngine() {
        if engine.isRunning {
            engine.pause()
        }
    }

    private func captureGenerativeElapsed() {
        if let generativeAnchor {
            generativeElapsed += Date().timeIntervalSince(generativeAnchor)
            self.generativeAnchor = nil
        }
    }

    private func currentGenerativeElapsed() -> TimeInterval {
        var elapsed = generativeElapsed
        if let generativeAnchor {
            elapsed += Date().timeIntervalSince(generativeAnchor)
        }
        return elapsed
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            model?.statusMessage = "Audio couldn't take the playback session."
        }
    }

    private func ensureEngine() throws {
        if engineReady { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw URLError(.cannotDecodeContentData)
        }
        let box = renderBox
        let rate = sampleRate
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let first = buffers.first, let data = first.mData else { return noErr }
            if buffers.count >= 2, let rightData = buffers[1].mData {
                box.render(
                    frameCount: Int(frameCount),
                    sampleRate: rate,
                    left: data.assumingMemoryBound(to: Float.self),
                    right: rightData.assumingMemoryBound(to: Float.self)
                )
            } else {
                let interleaved = data.assumingMemoryBound(to: Float.self)
                let frames = Int(frameCount)
                var left = [Float](repeating: 0, count: frames)
                var right = [Float](repeating: 0, count: frames)
                left.withUnsafeMutableBufferPointer { leftBuffer in
                    right.withUnsafeMutableBufferPointer { rightBuffer in
                        guard let leftPointer = leftBuffer.baseAddress, let rightPointer = rightBuffer.baseAddress else { return }
                        box.render(frameCount: frames, sampleRate: rate, left: leftPointer, right: rightPointer)
                    }
                }
                for index in 0..<frames {
                    interleaved[index * 2] = left[index]
                    interleaved[index * 2 + 1] = right[index]
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        sourceNode = node
        engineReady = true
    }

    private func observePlayer() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                guard self.model?.session.route == .catalog else { return }
                let duration = self.player.currentItem?.duration.seconds ?? 0
                let safeDuration = duration.isFinite ? duration : 0
                self.model?.updateCatalogClock(position: time.seconds, duration: safeDuration)
            }
        }
        let ended = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.model?.handleTrackEnded()
            }
        }
        let interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw),
                  type == .began else { return }
            Task { @MainActor in
                self?.model?.pauseForInterruption()
            }
        }
        observers = [ended, interruption]
    }

    private func installCommands() {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.model?.remotePlay() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.model?.remotePause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.model?.togglePlay() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.model?.remoteNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.model?.remotePrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let position = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.model?.seek(to: position.positionTime) }
            return .success
        }
    }

    private func publishCatalog(track: Track, playing: Bool) {
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = true
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album ?? "Matthew Finley",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: model?.position ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: false,
        ]
        if let duration = model?.duration, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        } else if let ms = track.durationMs {
            info[MPMediaItemPropertyPlaybackDuration] = Double(ms) / 1000
        }
        info[MPMediaItemPropertyArtwork] = artwork(title: track.title)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func publishGenerative(parameters: GenerativeParameters, playing: Bool) {
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = false
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: parameters.preset.displayName,
            MPMediaItemPropertyArtist: ArtistName.display,
            MPMediaItemPropertyAlbumTitle: "Generative",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentGenerativeElapsed(),
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPMediaItemPropertyArtwork: artwork(title: parameters.preset.displayName),
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func artwork(title: String) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { size in
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor(red: 0.09, green: 0.07, blue: 0.06, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor(red: 0.91, green: 0.65, blue: 0.29, alpha: 1).setFill()
                let width = size.width * 0.08
                let heights: [CGFloat] = [0.34, 0.52, 0.70, 0.48, 0.30]
                let gap = size.width * 0.035
                let total = CGFloat(heights.count) * width + CGFloat(heights.count - 1) * gap
                var x = (size.width - total) / 2
                for height in heights {
                    let bar = size.height * height
                    let rect = CGRect(x: x, y: (size.height - bar) / 2, width: width, height: bar)
                    context.cgContext.addPath(UIBezierPath(roundedRect: rect, cornerRadius: width / 3).cgPath)
                    context.cgContext.fillPath()
                    x += width + gap
                }
                _ = title
            }
        }
    }
}
