import Foundation
import SwiftUI

enum DownloadKind {
    case audio(StreamQuality)
    case video
}

@MainActor
final class OnlineStore: ObservableObject {

    @Published var query = ""
    @Published var source: OnlineSource = .soundcloud
    @Published private(set) var results: [OnlineTrack] = []
    @Published private(set) var isSearching = false
    @Published private(set) var busy: Set<String> = []
    @Published var errorText: String?
    @Published private(set) var bridgeReady = false
    @Published private(set) var lastQuery = ""
    /// Chi ha risposto all'ultima ricerca YouTube: utile quando qualcosa non va.
    @Published private(set) var backend = "—"
    @Published var quality: StreamQuality = StreamQuality.preferred {
        didSet { StreamQuality.preferred = quality }
    }

    let downloads = DownloadManager.shared
    private var searchTask: Task<Void, Never>?

    // MARK: - stato del ponte (resta come riserva per YouTube)

    func refreshSources() async {
        await PipedClient.refreshInstanceList()
        await refreshBridge()
    }

    func refreshBridge() async {
        guard BridgeClient.isConfigured else {
            bridgeReady = false
            return
        }
        bridgeReady = await BridgeClient.health()
    }

    var connectionNote: String {
        let net = NetworkMonitor.shared.connectionLabel
        let q = quality == .auto ? "\(quality.label) → \(quality.resolved.label.lowercased())" : quality.label
        return "\(net) · \(q)"
    }

    // MARK: - ricerca

    func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searchTask?.cancel()
        errorText = nil
        isSearching = true
        lastQuery = text
        let chosen = source

        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let found: [OnlineTrack]
                switch chosen {
                case .soundcloud:
                    found = try await SoundCloudClient.search(text)
                case .youtube:
                    found = try await self.searchYouTube(text)
                }
                if Task.isCancelled { return }
                self.results = found
                self.isSearching = false
                if found.isEmpty { self.errorText = "Nessun risultato per \"\(text)\"" }
            } catch {
                if Task.isCancelled { return }
                self.isSearching = false
                self.results = []
                self.errorText = error.localizedDescription
            }
        }
    }

    /// Prima Piped, che funziona ovunque; se tutte le istanze sono giù e c'è il
    /// computer acceso, si ripiega sul ponte con yt-dlp.
    private func searchYouTube(_ text: String) async throws -> [OnlineTrack] {
        let found = try await YouTubeClient.search(text, allowBridge: bridgeReady || BridgeClient.isConfigured)
        backend = YouTubeClient.lastBackend
        return found
    }

    /// Con l'accesso fatto, a ricerca vuota mostriamo i tuoi preferiti.
    func loadLikes() {
        searchTask?.cancel()
        errorText = nil
        isSearching = true
        lastQuery = ""
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let found = try await SoundCloudClient.likes()
                if Task.isCancelled { return }
                self.results = found
                self.isSearching = false
                if found.isEmpty { self.errorText = "Nessun brano fra i tuoi preferiti" }
            } catch {
                if Task.isCancelled { return }
                self.isSearching = false
                self.errorText = error.localizedDescription
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        results = []
        errorText = nil
        lastQuery = ""
    }

    // MARK: - ascolto

    func play(_ track: OnlineTrack, in library: LibraryStore) {
        guard !busy.contains(track.id) else { return }
        errorText = nil

        if track.isProtected {
            errorText = "\"\(track.title)\" è protetto con DRM da SoundCloud: iOS non può riprodurlo."
            return
        }

        // se è già sul telefono non sprechiamo dati: si ascolta il file
        if let local = track.localFile,
           let known = library.tracks.first(where: { $0.id == local.lastPathComponent }) {
            PlayerEngine.shared.play(tracks: [known], startAt: 0)
            return
        }

        busy.insert(track.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.streamURL(for: track)
                PlayerEngine.shared.playStream(track, url: url)
            } catch {
                self.errorText = error.localizedDescription
            }
            self.busy.remove(track.id)
        }
    }

    private func streamURL(for track: OnlineTrack) async throws -> URL {
        switch track.source {
        case .soundcloud:
            return try await SoundCloudClient.streamURL(for: track)
        case .youtube:
            guard let videoID = track.resolveHint else { throw PipedClient.PipedError.noAudio }
            // yt-dlp sul PC è l'unica via che YouTube non blocca: se c'è, prima lui
            if bridgeReady, let viaBridge = try? await BridgeClient.streamURL(for: track) {
                backend = "ponte sul PC"
                return viaBridge
            }
            let url = try await YouTubeClient.resolveAudio(videoID: videoID, quality: quality)
            backend = YouTubeClient.lastBackend
            return url
        }
    }

    // MARK: - download

    func download(_ track: OnlineTrack, kind: DownloadKind, into library: LibraryStore,
                  addTo playlist: Playlist? = nil) {
        guard !busy.contains(track.id), !downloads.isRunning(track.id) else { return }
        busy.insert(track.id)
        errorText = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                switch kind {
                case .audio(let requested):
                    try await self.downloadAudio(track, quality: requested, into: library, addTo: playlist)
                case .video:
                    try await self.downloadVideo(track)
                }
            } catch {
                self.errorText = error.localizedDescription
            }
            self.busy.remove(track.id)
        }
    }

    private func downloadAudio(_ track: OnlineTrack, quality requested: StreamQuality,
                               into library: LibraryStore,
                               addTo playlist: Playlist? = nil) async throws {
        LibraryPaths.ensureDirectories()

        if let existing = track.localFile {
            if let playlist {
                library.add(trackIDs: [existing.lastPathComponent], to: playlist)
                library.lastMessage = "Aggiunto a \(playlist.name)"
            } else {
                library.lastMessage = "Già in libreria"
            }
            return
        }

        if track.isProtected {
            throw HLSDownloader.HLSError.encrypted
        }

        var remote: URL
        var ext = "m4a"

        switch track.source {
        case .soundcloud:
            remote = try await SoundCloudClient.streamURL(for: track, preferDownloadable: true)
            ext = "mp3"
            // niente transcodifica progressiva: scarichiamo i segmenti e li uniamo
            if HLSDownloader.isPlaylist(remote) {
                let destination = LibraryPaths.uniqueDestination(for: track.fileName(ext: "mp3"))
                downloads.beginManual(id: track.id, title: track.title,
                                      fileName: destination.lastPathComponent)
                do {
                    try await HLSDownloader.download(playlist: remote, to: destination) { value in
                        Task { @MainActor in self.downloads.updateManual(id: track.id, progress: value) }
                    }
                } catch {
                    downloads.endManual(id: track.id)
                    try? FileManager.default.removeItem(at: destination)
                    throw error
                }
                downloads.endManual(id: track.id)
                await finishImport(track: track, destination: destination,
                                   library: library, playlist: playlist)
                return
            }
            guard await StreamProbe.isServed(remote) else {
                throw SoundCloudClient.ClientError.noStream
            }
        case .youtube:
            guard let videoID = track.resolveHint else { throw PipedClient.PipedError.noAudio }
            remote = try await YouTubeClient.resolveAudio(videoID: videoID, quality: requested)
            backend = YouTubeClient.lastBackend
            ext = "m4a"
        }

        let destination = LibraryPaths.uniqueDestination(for: track.fileName(ext: ext))
        _ = try await downloads.download(remote, to: destination,
                                         id: track.id, title: track.title)
        await finishImport(track: track, destination: destination,
                           library: library, playlist: playlist)
    }

    /// Copertina, riscansione ed eventuale playlist: uguale per ogni strada.
    private func finishImport(track: OnlineTrack, destination: URL,
                              library: LibraryStore, playlist: Playlist?) async {
        var artwork: Data?
        if let artURL = track.artworkURL {
            artwork = try? await URLSession.shared.data(from: artURL).0
        }
        await library.rescan()
        if let artwork {
            library.attachArtwork(artwork, toFileNamed: destination.lastPathComponent)
        }
        if let playlist {
            library.add(trackIDs: [destination.lastPathComponent], to: playlist)
            library.lastMessage = "\(track.title) → \(playlist.name)"
        } else {
            library.lastMessage = "Aggiunto: \(destination.lastPathComponent)"
        }
    }

    private func downloadVideo(_ track: OnlineTrack) async throws {
        guard track.source == .youtube, let videoID = track.resolveHint else {
            throw PipedClient.PipedError.noAudio
        }
        let options = try await YouTubeClient.videoOptions(for: videoID)
        guard let option = PipedClient.bestVideo(options) else {
            throw PipedClient.PipedError.noAudio
        }
        let folder = LibraryPaths.documents.appendingPathComponent("Video", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(track.fileName(ext: "mp4"))
        _ = try await downloads.download(option.url, to: destination,
                                         id: track.id, title: track.title)
        errorText = nil
    }

    // MARK: - stato per la vista

    func isBusy(_ track: OnlineTrack) -> Bool {
        busy.contains(track.id) || downloads.isRunning(track.id)
    }

    func progress(for track: OnlineTrack) -> Double? {
        downloads.progress(for: track.id)
    }
}
