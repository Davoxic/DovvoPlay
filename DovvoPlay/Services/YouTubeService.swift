import Foundation
import UIKit

public class YouTubeService: ObservableObject {
    public static let shared = YouTubeService()
    private init() {}

    public var lastFailureReason: String?

    private var cacheDirectory: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("yt_cache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // --- SEARCH ---

    public func search(_ query: String) async throws -> [YouTubeTrack] {
        return try await search(query: query)
    }

    public func search(query: String) async throws -> [YouTubeTrack] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }

        // 1. Direct YouTube video URL
        if clean.contains("youtube.com/watch") || clean.contains("youtu.be/") {
            if let videoId = extractVideoId(from: clean) {
                if let track = try? await fetchVideoDetails(videoId: videoId) {
                    return [track]
                }
            }
        }

        // 2. Query YouTube Innertube Search API
        let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/search")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20240101.00.00",
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "query": clean
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback scraping
            return try await fallbackSearch(query: clean)
        }

        var results: [YouTubeTrack] = []
        if let contents = json["contents"] as? [String: Any],
           let twoColumn = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
           let primary = twoColumn["primaryContents"] as? [String: Any],
           let sectionList = primary["sectionListRenderer"] as? [String: Any],
           let subContents = sectionList["contents"] as? [[String: Any]] {

            for sub in subContents {
                guard let itemSection = sub["itemSectionRenderer"] as? [String: Any],
                      let items = itemSection["contents"] as? [[String: Any]] else { continue }

                for item in items {
                    guard let videoRenderer = item["videoRenderer"] as? [String: Any],
                          let videoId = videoRenderer["videoId"] as? String else { continue }

                    let title = (videoRenderer["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                    let titleStr = title?.compactMap { $0["text"] as? String }.joined() ?? "Video YouTube"

                    let ownerRuns = ((videoRenderer["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]])
                    let author = ownerRuns?.compactMap { $0["text"] as? String }.joined() ?? "YouTube"

                    let lengthText = (videoRenderer["lengthText"] as? [String: Any])?["simpleText"] as? String ?? ""
                    let duration = parseDurationString(lengthText)

                    let thumb = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
                    let videoUrl = "https://www.youtube.com/watch?v=\(videoId)"

                    results.append(YouTubeTrack(
                        id: videoId,
                        title: titleStr,
                        author: author,
                        duration: duration,
                        thumbnailUrl: thumb,
                        url: videoUrl
                    ))
                }
            }
        }

        if results.isEmpty {
            return try await fallbackSearch(query: clean)
        }

        return results
    }

    private func fallbackSearch(query: String) async throws -> [YouTubeTrack] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        guard let rangeStart = html.range(of: "var ytInitialData = "),
              let rangeEnd = html[rangeStart.upperBound...].range(of: ";</script>") else {
            return []
        }

        let jsonStr = String(html[rangeStart.upperBound..<rangeEnd.lowerBound])
        guard let jsonData = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }

        var results: [YouTubeTrack] = []
        if let contents = json["contents"] as? [String: Any],
           let twoColumn = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
           let primary = twoColumn["primaryContents"] as? [String: Any],
           let sectionList = primary["sectionListRenderer"] as? [String: Any],
           let subContents = sectionList["contents"] as? [[String: Any]] {

            for sub in subContents {
                guard let itemSection = sub["itemSectionRenderer"] as? [String: Any],
                      let items = itemSection["contents"] as? [[String: Any]] else { continue }

                for item in items {
                    guard let videoRenderer = item["videoRenderer"] as? [String: Any],
                          let videoId = videoRenderer["videoId"] as? String else { continue }

                    let title = (videoRenderer["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                    let titleStr = title?.compactMap { $0["text"] as? String }.joined() ?? "Video"

                    let ownerRuns = ((videoRenderer["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]])
                    let author = ownerRuns?.compactMap { $0["text"] as? String }.joined() ?? "YouTube"

                    let lengthText = (videoRenderer["lengthText"] as? [String: Any])?["simpleText"] as? String ?? ""
                    let duration = parseDurationString(lengthText)

                    results.append(YouTubeTrack(
                        id: videoId,
                        title: titleStr,
                        author: author,
                        duration: duration,
                        thumbnailUrl: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg",
                        url: "https://www.youtube.com/watch?v=\(videoId)"
                    ))
                }
            }
        }
        return results
    }

    private func extractVideoId(from urlStr: String) -> String? {
        if let range = urlStr.range(of: "v=") {
            let id = urlStr[range.upperBound...].components(separatedBy: "&")[0]
            return String(id)
        }
        if let range = urlStr.range(of: "youtu.be/") {
            let id = urlStr[range.upperBound...].components(separatedBy: "?")[0]
            return String(id)
        }
        return nil
    }

    private func parseDurationString(_ text: String) -> TimeInterval {
        let parts = text.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 0
    }

    public func fetchVideoDetails(videoId: String) async throws -> YouTubeTrack? {
        let oembedUrl = URL(string: "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoId)&format=json")!
        let (data, response) = try await URLSession.shared.data(from: oembedUrl)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let title = json["title"] as? String ?? "Video YouTube"
        let author = json["author_name"] as? String ?? "YouTube"
        let thumb = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"

        return YouTubeTrack(
            id: videoId,
            title: title,
            author: author,
            duration: 0,
            thumbnailUrl: thumb,
            url: "https://www.youtube.com/watch?v=\(videoId)"
        )
    }

    // --- STREAM EXTRACTION ---

    public func getPlayableStreamUrl(videoId: String) async -> URL? {
        lastFailureReason = nil

        // Query YouTube Innertube Player API with Android VR client
        let playerURL = URL(string: "https://www.youtube.com/youtubei/v1/player")!
        var request = URLRequest(url: playerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID_VR",
                    "clientVersion": "1.60.19",
                    "deviceMake": "Oculus",
                    "deviceModel": "Quest 3",
                    "osName": "Android",
                    "osVersion": "12",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": videoId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                lastFailureReason = "Risposta non valida dai server YouTube."
                return nil
            }

            guard let streamingData = json["streamingData"] as? [String: Any] else {
                lastFailureReason = "Formati audio non disponibili per questo video."
                return nil
            }

            // Look for audio formats (AAC/m4a - itag 140)
            let adaptive = (streamingData["adaptiveFormats"] as? [[String: Any]]) ?? []
            let formats = (streamingData["formats"] as? [[String: Any]]) ?? []
            let allFormats = adaptive + formats

            // 1. Audio-only AAC/m4a
            for format in allFormats {
                let mime = (format["mimeType"] as? String)?.lowercased() ?? ""
                if (mime.contains("audio/mp4") || mime.contains("mp4a")) && !mime.contains("opus") {
                    if let urlStr = format["url"] as? String, let url = URL(string: urlStr) {
                        return url
                    }
                }
            }

            // 2. Muxed MP4 (with AAC audio)
            for format in allFormats {
                let mime = (format["mimeType"] as? String)?.lowercased() ?? ""
                if mime.contains("video/mp4") && !mime.contains("opus") {
                    if let urlStr = format["url"] as? String, let url = URL(string: urlStr) {
                        return url
                    }
                }
            }

            lastFailureReason = "Questo video è disponibile solo in formato Opus (non supportato direttamente da iOS). Utilizza il PC Companion per scaricarlo in MP3."
            return nil
        } catch {
            lastFailureReason = "Errore di connessione: \(error.localizedDescription)"
            return nil
        }
    }

    public func getLocalAudioFile(trackId: String) -> URL? {
        let safeId = trackId.replacingOccurrences(of: "yt_", with: "")

        // 1. Check Music Directory
        let musicDir = LibraryService.shared.musicDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for f in files {
                if f.lastPathComponent.contains(safeId) {
                    let size = (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    if size > 50000 {
                        return f
                    }
                }
            }
        }

        // 2. Check Cache Directory
        let cacheDir = self.cacheDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for f in files {
                if f.lastPathComponent.contains(safeId) {
                    let size = (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    if size > 50000 {
                        return f
                    }
                }
            }
        }

        return nil
    }

    public func downloadToCache(videoId: String, title: String) async -> URL? {
        let safeId = videoId.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let targetURL = cacheDirectory.appendingPathComponent("yt_\(safeId).m4a")

        if FileManager.default.fileExists(atPath: targetURL.path),
           let size = try? targetURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 50000 {
            return targetURL
        }

        guard let streamURL = await getPlayableStreamUrl(videoId: videoId) else { return nil }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: streamURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.moveItem(at: tempURL, to: targetURL)
            return targetURL
        } catch {
            return nil
        }
    }

    public struct AudioStreamInfo {
        public let url: String
        public init(url: String) { self.url = url }
    }

    public func extractAudioStream(_ videoId: String) async -> AudioStreamInfo? {
        if let url = await getPlayableStreamUrl(videoId: videoId) {
            return AudioStreamInfo(url: url.absoluteString)
        }
        return nil
    }

    public func downloadAudioStream(_ videoId: String, _ title: String, onProgress: ((Double) -> Void)? = nil) async -> URL? {
        return await downloadAudioStream(videoId: videoId, title: title, onProgress: onProgress)
    }

    public func downloadAudioStream(videoId: String, title: String, onProgress: ((Double) -> Void)? = nil) async -> URL? {
        let safeName = title.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let safeId = videoId.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let musicDir = LibraryService.shared.musicDirectory
        let targetURL = musicDir.appendingPathComponent("\(safeName)_\(safeId).m4a")

        if FileManager.default.fileExists(atPath: targetURL.path),
           let size = try? targetURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 50000 {
            return targetURL
        }

        // Fast copy from cache if already downloaded
        if let cached = getLocalAudioFile(trackId: videoId) {
            try? FileManager.default.copyItem(at: cached, to: targetURL)
            await LibraryService.shared.scanLibrary()
            return targetURL
        }

        guard let streamURL = await getPlayableStreamUrl(videoId: videoId) else { return nil }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: streamURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.moveItem(at: tempURL, to: targetURL)

            await LibraryService.shared.scanLibrary()
            return targetURL
        } catch {
            return nil
        }
    }
}
