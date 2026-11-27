import Foundation
import PlayerCore
import SwiftUI
import WidgetKit

@MainActor
final class PlayerModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var queue = PlaybackQueue.create([])
    @Published var favorites = FavoritesStore()
    @Published var cache = OfflineCacheStore()
    @Published var downloading = Set<String>()
    @Published var session = PlaybackSession()
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var generative = GenerativeParameters(preset: .deepFocus)
    @Published var energy = VisualEnergy.silent
    @Published var statusMessage: String?
    @Published var showNowPlaying = false
    @Published var offlineOnly = false
    @Published var manifestURLString = CatalogEndpoints.defaultManifestURL.absoluteString

    private let audio = AudioController()
    private let downloads = OfflineDownloadManager()
    private var pendingLink: PlayerDeepLink?
    private var poll: Timer?

    var showsMiniPlayer: Bool { session.route != .idle }

    var currentTrack: Track? {
        guard session.route == .catalog, let id = session.trackID else { return nil }
        return tracks.first { $0.id == id }
    }

    var nowTitle: String {
        if session.route == .generative { return generative.preset.displayName }
        return currentTrack?.title ?? "Matthew Finley"
    }

    var nowSubtitle: String {
        if session.route == .generative { return "Generative · \(ArtistName.display)" }
        return currentTrack?.artist ?? ArtistName.display
    }

    var visibleTracks: [Track] {
        LibraryBrowser.applyingOfflineFilter(tracks, cache: cache, offlineOnly: offlineOnly)
    }

    var upNext: [Track] {
        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return queue.upNextIDs.compactMap { lookup[$0] }
    }

    init() {
        audio.model = self
        audio.prepare()
        downloads.onChange = { [weak self] cache, downloading in
            self?.cache = cache
            self?.downloading = downloading
        }
        downloads.load()
        cache = downloads.cache
        favorites = SuiteStore.loadFavorites()
        if let saved = SuiteStore.defaults.string(forKey: SuiteStore.manifestKey), !saved.isEmpty {
            manifestURLString = saved
        }
        tracks = CatalogService.loadBundled()
        queue = PlaybackQueue.create(tracks.map(\.id))
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollEnergy() }
        }
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
        Task { await refresh() }
    }

    func refresh() async {
        var groups: [[Track]] = [CatalogService.loadBundled()]
        var notes: [String] = []
        if let url = URL(string: manifestURLString), url.scheme == "https" {
            let remote = await CatalogService.loadRemoteManifest(from: url)
            if remote.isEmpty {
                notes.append("The catalog manifest is unreachable.")
            } else {
                groups.append(remote)
            }
        }
        do {
            groups.append(try await CatalogService.loadSoundCloud())
        } catch {
            let snapshot = CatalogService.loadSnapshot()
            if !snapshot.isEmpty { groups.append(snapshot) }
            notes.append("The public feed is unreachable. Saved catalog metadata is on this iPhone.")
        }
        let merged = CatalogMerger.merge(groups)
        tracks = merged
        let keep = session.trackID
        queue = PlaybackQueue.replaceOrder(queue, ids: merged.map(\.id), keepID: keep)
        if merged.isEmpty {
            statusMessage = "No tracks yet."
        } else if merged.contains(where: { !$0.placeholder }) {
            statusMessage = nil
        } else if !notes.isEmpty {
            statusMessage = "On-device demos are ready. The public catalog will appear when the connection succeeds."
        } else {
            statusMessage = nil
        }
        if let pendingLink {
            self.pendingLink = nil
            open(pendingLink)
        }
    }

    func saveManifestURL() {
        let trimmed = manifestURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        manifestURLString = trimmed
        SuiteStore.defaults.set(trimmed, forKey: SuiteStore.manifestKey)
        Task { await refresh() }
    }

    func play(_ track: Track, in collection: [Track]? = nil) {
        let list = (collection?.isEmpty == false ? collection! : visibleTracks)
        if collection == nil, queue.order.contains(track.id) {
            queue = PlaybackQueue.play(queue, id: track.id)
        } else {
            queue = PlaybackQueue.create(list.map(\.id))
            queue = PlaybackQueue.play(queue, id: track.id)
        }
        beginCatalog(track, present: true)
    }

    func togglePlay() {
        guard session.route != .idle else { return }
        if session.isPlaying {
            session.setPlaying(false)
            audio.pause()
        } else {
            session.setPlaying(true)
            audio.resume()
        }
        writeSnapshot()
    }

    func remotePlay() {
        guard session.route != .idle else { return }
        session.setPlaying(true)
        audio.resume()
        writeSnapshot()
    }

    func remotePause() {
        session.setPlaying(false)
        audio.pause()
        writeSnapshot()
    }

    func pauseForInterruption() {
        session.setPlaying(false)
        audio.pause()
        writeSnapshot()
    }

    func seek(to seconds: Double) {
        guard session.route == .catalog else { return }
        position = seconds
        audio.seek(to: seconds)
    }

    func skipNext() {
        if session.route == .generative {
            stepPreset(1)
            return
        }
        guard let next = PlaybackQueue.nextIndex(queue) else {
            session.setPlaying(false)
            audio.pause()
            writeSnapshot()
            return
        }
        queue.index = next
        guard let track = track(id: queue.currentID) else { return }
        beginCatalog(track, present: false)
    }

    func skipPrevious() {
        if session.route == .generative {
            stepPreset(-1)
            return
        }
        let target = PlaybackQueue.previousTarget(queue, currentTime: position)
        if target.restart {
            seek(to: 0)
            return
        }
        queue.index = target.index
        guard let track = track(id: queue.currentID) else { return }
        beginCatalog(track, present: false)
    }

    func remoteNext() { skipNext() }
    func remotePrevious() { skipPrevious() }

    func cycleRepeat() {
        queue.repeatMode = PlaybackQueue.cycleRepeat(queue.repeatMode)
        Haptics.tap()
    }

    func toggleShuffle() {
        queue = PlaybackQueue.toggleShuffle(queue)
        Haptics.tap()
    }

    func removeUpNext(at offsets: IndexSet) {
        let start = queue.index + 1
        for offset in offsets.sorted(by: >) {
            queue = PlaybackQueue.remove(queue, at: start + offset)
        }
    }

    func moveUpNext(from offsets: IndexSet, to destination: Int) {
        guard let source = offsets.first else { return }
        let start = queue.index + 1
        let from = start + source
        var to = start + destination
        if to > from { to -= 1 }
        queue = PlaybackQueue.move(queue, from: from, to: min(max(0, to), max(0, queue.order.count - 1)))
    }

    func toggleFavorite(_ id: String) {
        favorites.toggle(id)
        SuiteStore.saveFavorites(favorites)
    }

    func toggleDownload(_ track: Track) {
        if track.isBundled { return }
        if cache.contains(track.id) {
            downloads.remove(trackID: track.id)
            return
        }
        downloads.start(trackIDs: [track.id], tracks: tracks, playlistID: nil)
    }

    func download(tracks collection: [Track], playlistID: String) {
        Haptics.tap()
        downloads.start(trackIDs: collection.map(\.id), tracks: tracks, playlistID: playlistID)
    }

    func removeAllDownloads() {
        downloads.removeAll()
    }

    func formattedCacheSize() -> String {
        ByteCountFormatter.string(fromByteCount: cache.totalBytes, countStyle: .file)
    }

    func playGenerative(_ preset: GenerativePreset? = nil, present: Bool = false) {
        if let preset {
            generative.preset = preset
            generative.tempo = preset.defaultTempo
        }
        session.playGenerative(preset: generative.preset, seed: generative.seed)
        audio.playGenerative(generative)
        if present { showNowPlaying = true }
        writeSnapshot()
    }

    func setDensity(_ value: Double) {
        generative.density = value
        pushGenerativeKnobs()
    }

    func setWarmth(_ value: Double) {
        generative.warmth = value
        pushGenerativeKnobs()
    }

    func setTempo(_ value: Double) {
        generative.tempo = value
        pushGenerativeKnobs()
    }

    func setDrift(_ value: Double) {
        generative.drift = value
        pushGenerativeKnobs()
    }

    func newSeed() {
        Haptics.tap(.medium)
        generative.seed = SeedSource.next(after: generative.seed)
        if session.route == .generative {
            session.playGenerative(preset: generative.preset, seed: generative.seed)
            audio.updateGenerative(generative)
            writeSnapshot()
        }
    }

    func updateCatalogClock(position: Double, duration: Double) {
        guard session.route == .catalog else { return }
        self.position = position.isFinite ? position : 0
        self.duration = duration.isFinite ? duration : 0
    }

    func handleTrackEnded() {
        guard session.route == .catalog else { return }
        if queue.repeatMode == .one {
            seek(to: 0)
            audio.resume()
            return
        }
        if PlaybackQueue.nextIndex(queue) == nil {
            session.setPlaying(false)
            position = 0
            writeSnapshot()
            return
        }
        skipNext()
    }

    func handle(url: URL) {
        guard let link = PlayerDeepLink(url: url) else { return }
        switch link {
        case let .play(trackID):
            if tracks.contains(where: { $0.id == trackID }) {
                open(link)
            } else {
                pendingLink = link
            }
        case .generative:
            open(link)
        }
    }

    private func open(_ link: PlayerDeepLink) {
        switch link {
        case let .play(trackID):
            guard let track = tracks.first(where: { $0.id == trackID }) else {
                statusMessage = "That track isn't in the catalog on this iPhone."
                return
            }
            play(track, in: tracks)
        case let .generative(presetID):
            guard let preset = GenerativePreset(rawValue: presetID) else { return }
            playGenerative(preset, present: true)
        }
    }

    private func beginCatalog(_ track: Track, present: Bool) {
        guard let url = playbackURL(for: track) else {
            statusMessage = track.isBundled
                ? "The on-device demo couldn't be opened."
                : "That track has no audio file on this iPhone yet."
            return
        }
        session.playCatalog(trackID: track.id)
        position = 0
        duration = Double(track.durationMs ?? 0) / 1000
        audio.play(track: track, url: url)
        if present { showNowPlaying = true }
        statusMessage = nil
        writeSnapshot()
    }

    private func playbackURL(for track: Track) -> URL? {
        if let local = downloads.localFile(for: track.id) { return local }
        switch track.playback {
        case let .bundled(key):
            return Bundle.main.url(forResource: key, withExtension: "wav")
                ?? Bundle.main.url(forResource: key, withExtension: "caf")
        case let .remote(raw):
            guard let url = URL(string: raw), url.scheme == "https" || url.scheme == "http" else { return nil }
            return url
        case .page:
            return nil
        }
    }

    private func track(id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }

    private func stepPreset(_ direction: Int) {
        let all = GenerativePreset.allCases
        guard let index = all.firstIndex(of: generative.preset) else { return }
        let next = (index + direction + all.count) % all.count
        playGenerative(all[next])
    }

    private func pushGenerativeKnobs() {
        generative = generative.clamped()
        if session.route == .generative {
            audio.updateGenerative(generative)
        }
    }

    private func pollEnergy() {
        guard session.route == .generative, session.isPlaying else { return }
        energy = audio.pollEnergy()
    }

    private func writeSnapshot() {
        let snapshot: NowPlayingSnapshot
        switch session.route {
        case .catalog:
            if let track = currentTrack {
                snapshot = .catalog(track: track, isPlaying: session.isPlaying)
            } else {
                snapshot = .idle()
            }
        case .generative:
            snapshot = .generative(preset: generative.preset, isPlaying: session.isPlaying)
        case .idle:
            snapshot = .idle()
        }
        SuiteStore.saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
