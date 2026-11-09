import Foundation
import SwiftUI

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

    private var searchTask: Task<Void, Never>?

    // MARK: - ponte

    func refreshBridge() async {
        guard BridgeClient.isConfigured else {
            bridgeReady = false
            return
        }
        bridgeReady = await BridgeClient.health()
    }

    var bridgeAddress: String {
        BridgeClient.baseURL?.absoluteString ?? "nessuno"
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
                    found = try await BridgeClient.search(text)
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

    func clear() {
        searchTask?.cancel()
        results = []
        errorText = nil
        lastQuery = ""
    }

    // MARK: - ascolto

    func play(_ track: OnlineTrack) {
        guard !busy.contains(track.id) else { return }
        busy.insert(track.id)
        errorText = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let url: URL
                switch track.source {
                case .soundcloud: url = try await SoundCloudClient.streamURL(for: track)
                case .youtube:    url = try await BridgeClient.streamURL(for: track)
                }
                PlayerEngine.shared.playStream(track, url: url)
            } catch {
                self.errorText = error.localizedDescription
            }
            self.busy.remove(track.id)
        }
    }

    // MARK: - download

    func download(_ track: OnlineTrack, into library: LibraryStore) {
        guard !busy.contains(track.id) else { return }
        busy.insert(track.id)
        errorText = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                switch track.source {
                case .soundcloud:
                    try await self.downloadDirect(track, into: library)
                case .youtube:
                    let callback = LocalServer.shared.primaryURL
                    let name = try await BridgeClient.grab(track, callback: callback)
                    library.lastMessage = callback == nil
                        ? "Scaricato sul computer: \(name). Accendi il server Wi-Fi per riceverlo."
                        : "\(name) in arrivo dal computer"
                    await library.rescan()
                }
            } catch {
                self.errorText = error.localizedDescription
            }
            self.busy.remove(track.id)
        }
    }

    /// SoundCloud: scarica il file direttamente dal telefono, senza PC di mezzo.
    private func downloadDirect(_ track: OnlineTrack, into library: LibraryStore) async throws {
        let streamURL = try await SoundCloudClient.streamURL(for: track)
        let raw = streamURL.absoluteString
        if raw.contains(".m3u8") || raw.contains("/hls/") {
            throw SoundCloudClient.ClientError.noStream
        }

        let (temp, response) = try await URLSession.shared.download(from: streamURL)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw SoundCloudClient.ClientError.noStream
        }

        LibraryPaths.ensureDirectories()
        let destination = LibraryPaths.uniqueDestination(for: track.fileName)
        try FileManager.default.moveItem(at: temp, to: destination)

        // copertina: la scarichiamo prima della riscansione così la ritrova subito
        var artwork: Data?
        if let artURL = track.artworkURL {
            artwork = try? await URLSession.shared.data(from: artURL).0
        }

        await library.rescan()
        if let artwork {
            library.attachArtwork(artwork, toFileNamed: destination.lastPathComponent)
        }
        library.lastMessage = "Aggiunto: \(destination.lastPathComponent)"
    }

    func isBusy(_ track: OnlineTrack) -> Bool { busy.contains(track.id) }
}
