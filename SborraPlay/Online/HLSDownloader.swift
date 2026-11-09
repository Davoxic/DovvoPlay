import Foundation

/// SoundCloud serve molti brani solo come playlist HLS, che non è un file
/// scaricabile. Quando i segmenti sono MP3 però basta incollarli uno dietro
/// l'altro per ottenere un mp3 valido: è così che rendiamo scaricabili anche
/// i brani senza transcodifica progressiva.
enum HLSDownloader {

    enum HLSError: LocalizedError {
        case encrypted
        case notConcatenable
        case empty

        var errorDescription: String? {
            switch self {
            case .encrypted:
                return "Brano protetto: SoundCloud lo cifra e non si può salvare"
            case .notConcatenable:
                return "Questo brano si può solo ascoltare, non salvare"
            case .empty:
                return "La playlist non contiene segmenti"
            }
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    static func isPlaylist(_ url: URL) -> Bool {
        let raw = url.absoluteString
        return raw.contains(".m3u8") || raw.contains("/hls/") || raw.contains("playback.media-streaming")
    }

    /// Scarica tutti i segmenti e li concatena. Solo per segmenti MP3.
    static func download(playlist: URL, to destination: URL,
                         progress: @escaping (Double) -> Void) async throws {
        let (data, response) = try await session.data(from: playlist)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else {
            throw HLSError.empty
        }

        if text.contains("#EXT-X-KEY") { throw HLSError.encrypted }
        // EXT-X-MAP significa segmenti fMP4: andrebbero rimuxati, non concatenati
        if text.contains("#EXT-X-MAP") { throw HLSError.notConcatenable }

        let segments: [URL] = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("http") }
            .compactMap { URL(string: $0) }

        guard !segments.isEmpty else { throw HLSError.empty }
        guard segments.contains(where: { $0.absoluteString.contains(".mp3") })
                || !text.contains("audio/mp4") else {
            throw HLSError.notConcatenable
        }

        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        fm.createFile(atPath: destination.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: destination) else {
            throw HLSError.notConcatenable
        }
        defer { try? handle.close() }

        for (index, segment) in segments.enumerated() {
            let (chunk, segmentResponse) = try await session.data(from: segment)
            if let code = (segmentResponse as? HTTPURLResponse)?.statusCode, code >= 400 {
                throw HLSError.notConcatenable
            }
            try handle.write(contentsOf: chunk)
            progress(Double(index + 1) / Double(segments.count))
        }
    }
}
