import Foundation
import PlayerCore

final class OfflineDownloadManager: NSObject, URLSessionDownloadDelegate {
    var onChange: ((OfflineCacheStore, Set<String>) -> Void)?
    private(set) var cache = OfflineCacheStore()
    private(set) var downloading = Set<String>()
    private var playlistForTask: [Int: String] = [:]
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func load() {
        let index = directory().appendingPathComponent("index.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: index),
              let store = try? decoder.decode(OfflineCacheStore.self, from: data) else {
            return
        }
        cache = store.prunedToExistingFiles(in: directory())
    }

    func start(trackIDs: [String], tracks: [Track], playlistID: String?) {
        let plan = DownloadPlanner.plan(trackIDs: trackIDs, tracks: tracks, cache: cache)
        let lookup = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in plan.trackIDs {
            guard let track = lookup[id], let url = RemoteAudio.downloadURL(for: track) else { continue }
            if downloading.contains(id) { continue }
            downloading.insert(id)
            let task = session.downloadTask(with: url)
            task.taskDescription = id
            if let playlistID {
                playlistForTask[task.taskIdentifier] = playlistID
            }
            task.resume()
        }
        publish()
    }

    func remove(trackID: String) {
        cache.remove(trackID: trackID)
        let file = directory().appendingPathComponent(fileName(for: trackID))
        try? FileManager.default.removeItem(at: file)
        save()
        publish()
    }

    func removeAll() {
        let ids = cache.records.map(\.id)
        cache.removeAll()
        for id in ids {
            try? FileManager.default.removeItem(at: directory().appendingPathComponent(fileName(for: id)))
        }
        save()
        publish()
    }

    func localFile(for trackID: String) -> URL? {
        guard cache.contains(trackID) else { return nil }
        let url = directory().appendingPathComponent(fileName(for: trackID))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = downloadTask.taskDescription else { return }
        let destination = directory().appendingPathComponent(fileName(for: id))
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            let bytes = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            let playlist = playlistForTask[downloadTask.taskIdentifier]
            DispatchQueue.main.async {
                self.cache.markDownloaded(
                    trackID: id,
                    byteCount: bytes,
                    downloadedAt: Date(),
                    playlistID: playlist
                )
                self.downloading.remove(id)
                self.playlistForTask[downloadTask.taskIdentifier] = nil
                self.save()
                self.publish()
            }
        } catch {
            DispatchQueue.main.async {
                self.downloading.remove(id)
                self.publish()
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let id = task.taskDescription else { return }
        DispatchQueue.main.async {
            self.downloading.remove(id)
            self.publish()
        }
    }

    private func publish() {
        onChange?(cache, downloading)
    }

    private func save() {
        let index = directory().appendingPathComponent("index.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(cache) {
            try? data.write(to: index, options: .atomic)
        }
    }

    private func directory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent(OfflineAudioLocation.directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func fileName(for trackID: String) -> String {
        URL(fileURLWithPath: OfflineAudioLocation.relativePath(for: trackID)).lastPathComponent
    }
}

private extension OfflineCacheStore {
    func prunedToExistingFiles(in directory: URL) -> OfflineCacheStore {
        var copy = self
        let survivors = records.filter { record in
            let name = URL(fileURLWithPath: record.relativePath).lastPathComponent
            return FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
        }
        if survivors.count != records.count {
            copy = OfflineCacheStore(records: survivors)
        }
        return copy
    }
}
