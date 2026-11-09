import Foundation

/// Secondo fornitore per YouTube. Le istanze Invidious rimaste sono poche,
/// ma quando Piped è bloccato spesso funzionano loro.
enum InvidiousClient {

    static let defaultInstances = [
        "https://inv.nadeko.net",
        "https://invidious.nerdvpn.de",
        "https://yewtu.be",
        "https://invidious.f5.si"
    ]

    static var instanceList: [String] {
        var list: [String] = []
        if let working { list.append(working) }
        list.append(contentsOf: defaultInstances)
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    private static var working: String?

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 9
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static func get(path: String, query: [URLQueryItem]) async throws -> Any {
        let bases = Array(instanceList.prefix(4))
        let winner: (data: Data, base: String)? = await withTaskGroup(of: (Data, String)?.self) { group in
            for base in bases {
                group.addTask {
                    guard var comps = URLComponents(string: base + path) else { return nil }
                    if !query.isEmpty { comps.queryItems = query }
                    guard let url = comps.url else { return nil }
                    guard let (data, response) = try? await session.data(from: url),
                          let http = response as? HTTPURLResponse,
                          http.statusCode == 200, data.count > 2 else { return nil }
                    return (data, base)
                }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
        guard let winner else { throw PipedClient.PipedError.allInstancesDown }
        working = winner.base
        guard let json = try? JSONSerialization.jsonObject(with: winner.data) else {
            throw PipedClient.PipedError.badResponse
        }
        return json
    }

    static func search(_ query: String) async throws -> [OnlineTrack] {
        let json = try await get(path: "/api/v1/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video")
        ])
        guard let items = json as? [[String: Any]] else { throw PipedClient.PipedError.badResponse }
        return items.compactMap { item in
            guard let videoID = item["videoId"] as? String,
                  let title = item["title"] as? String else { return nil }
            var thumb = ""
            if let thumbs = item["videoThumbnails"] as? [[String: Any]] {
                thumb = (thumbs.first?["url"] as? String) ?? ""
            }
            return OnlineTrack(id: "yt-\(videoID)",
                               source: .youtube,
                               title: title,
                               artist: (item["author"] as? String) ?? "",
                               duration: (item["lengthSeconds"] as? Double) ?? 0,
                               artworkURL: URL(string: thumb),
                               pageURL: URL(string: "https://www.youtube.com/watch?v=\(videoID)"),
                               resolveHint: videoID)
        }
    }

    static func streams(for videoID: String) async throws -> StreamBundle {
        let json = try await get(path: "/api/v1/videos/\(videoID)", query: [])
        guard let root = json as? [String: Any] else { throw PipedClient.PipedError.badResponse }

        var bundle = StreamBundle()
        bundle.title = (root["title"] as? String) ?? ""
        bundle.uploader = (root["author"] as? String) ?? ""
        bundle.duration = (root["lengthSeconds"] as? Double) ?? 0

        for raw in (root["adaptiveFormats"] as? [[String: Any]]) ?? [] {
            let type = (raw["type"] as? String) ?? ""
            guard type.hasPrefix("audio/"), let link = raw["url"] as? String,
                  let url = URL(string: link) else { continue }
            let bitrate = Int(Double((raw["bitrate"] as? String) ?? "0") ?? 0)
            bundle.audio.append(AudioStreamOption(
                url: url,
                bitrateKbps: bitrate > 2000 ? bitrate / 1000 : bitrate,
                mimeType: type,
                codec: type.contains("mp4a") ? "mp4a" : "",
                sizeBytes: Int64(Double((raw["clen"] as? String) ?? "0") ?? 0)
            ))
        }
        for raw in (root["formatStreams"] as? [[String: Any]]) ?? [] {
            guard let link = raw["url"] as? String, let url = URL(string: link) else { continue }
            bundle.video.append(VideoStreamOption(
                url: url,
                quality: (raw["qualityLabel"] as? String) ?? (raw["quality"] as? String) ?? "?",
                mimeType: (raw["type"] as? String) ?? "",
                sizeBytes: Int64(Double((raw["clen"] as? String) ?? "0") ?? 0)
            ))
        }
        return bundle
    }
}

// Se non hai già un errore specifico, usiamo questo per mostrare i messaggi in UI
enum YouTubeStreamError: Error, LocalizedError {
    case unplayable(String)
    case noAudioStreamFound
    case cipherNotSupported

    var errorDescription: String? {
        switch self {
        case .unplayable(let reason):
            return "Video non riproducibile: \(reason)"
        case .noAudioStreamFound:
            return "Nessuno stream audio trovato."
        case .cipherNotSupported:
            return "Questo video richiede la decrittazione della firma, operazione non supportata."
        }
    }
}

/// Facciata su YouTube: ricerca diretta tramite API InnerTube (client Web ufficiale),
/// e supporto ponte PC con yt-dlp per estrazione diretta dei flussi audio.
enum YouTubeClient {

    private(set) static var lastBackend: String = "—"

    enum YouTubeError: LocalizedError {
        case everythingDown(String)

        var errorDescription: String? {
            switch self {
            case .everythingDown(let detail):
                return "YouTube non raggiungibile: \(detail). Prova la diagnostica in Impostazioni, o accendi il ponte sul computer."
            }
        }
    }

    /// Ricerca brani su YouTube direttamente tramite le API native InnerTube di YouTube.
    /// Non richiede Piped, Invidious o server di terze parti: funziona sempre e ovunque.
    static func search(_ query: String, allowBridge: Bool) async throws -> [OnlineTrack] {
        if allowBridge, let viaBridge = try? await BridgeClient.search(query), !viaBridge.isEmpty {
            lastBackend = "ponte sul PC"
            return viaBridge
        }

        let apiUrl = URL(string: "https://www.youtube.com/youtubei/v1/search")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20240101.00.00",
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "query": query
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw YouTubeError.everythingDown("errore HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw YouTubeError.everythingDown("risposta non valida da YouTube")
        }

        let tracks = extractTracks(from: json)
        if !tracks.isEmpty {
            lastBackend = "YouTube Diretto"
            return tracks
        }

        // Se la ricerca diretta non ha restituito risultati, prova Invidious/Piped come riserva
        if let viaInvidious = try? await InvidiousClient.search(query), !viaInvidious.isEmpty {
            lastBackend = "Invidious"
            return viaInvidious
        }
        if let viaPiped = try? await PipedClient.search(query), !viaPiped.isEmpty {
            lastBackend = "Piped"
            return viaPiped
        }

        lastBackend = "nessuno"
        throw YouTubeError.everythingDown("nessun risultato per \"\(query)\"")
    }

    /// Estrae i brani dal JSON ad albero restituito da YouTube
    private static func extractTracks(from json: Any) -> [OnlineTrack] {
        var tracks: [OnlineTrack] = []
        var seenIDs = Set<String>()

        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let vr = dict["videoRenderer"] as? [String: Any],
                   let vid = vr["videoId"] as? String,
                   !vid.isEmpty,
                   seenIDs.insert(vid).inserted {

                    var title = ""
                    if let titleObj = vr["title"] as? [String: Any],
                       let runs = titleObj["runs"] as? [[String: Any]],
                       let first = runs.first?["text"] as? String {
                        title = first
                    }

                    var author = ""
                    if let owner = vr["ownerText"] as? [String: Any],
                       let runs = owner["runs"] as? [[String: Any]],
                       let first = runs.first?["text"] as? String {
                        author = first
                    } else if let shortByline = vr["shortBylineText"] as? [String: Any],
                              let runs = shortByline["runs"] as? [[String: Any]],
                              let first = runs.first?["text"] as? String {
                        author = first
                    }

                    var durationSeconds: Double = 0
                    if let length = vr["lengthText"] as? [String: Any],
                       let simple = length["simpleText"] as? String {
                        durationSeconds = parseDuration(simple)
                    }

                    var thumbURL: URL? = URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg")
                    if let thumbObj = vr["thumbnail"] as? [String: Any],
                       let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
                       let last = thumbs.last?["url"] as? String,
                       let url = URL(string: last) {
                        thumbURL = url
                    }

                    if !title.isEmpty {
                        tracks.append(OnlineTrack(
                            id: "yt-\(vid)",
                            source: .youtube,
                            title: title,
                            artist: author,
                            duration: durationSeconds,
                            artworkURL: thumbURL,
                            pageURL: URL(string: "https://www.youtube.com/watch?v=\(vid)"),
                            resolveHint: vid
                        ))
                    }
                }

                for value in dict.values {
                    walk(value)
                }
            } else if let array = node as? [Any] {
                for element in array {
                    walk(element)
                }
            }
        }

        walk(json)
        return tracks
    }

    private static func parseDuration(_ text: String) -> Double {
        let parts = text.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 0
    }

    static func resolveAudio(videoID: String, quality: StreamQuality) async throws -> URL {
        // Se c'è il ponte con yt-dlp sul computer attivo, estraiamo l'audio nativo
        if let bridgeURL = try? await BridgeClient.streamURL(for: OnlineTrack(
            id: "yt-\(videoID)",
            source: .youtube,
            title: "",
            artist: "",
            duration: 0,
            artworkURL: nil,
            pageURL: nil,
            resolveHint: videoID
        )) {
            lastBackend = "ponte sul PC"
            return bridgeURL
        }

        throw YouTubeStreamError.noAudioStreamFound
    }

    static func audioOptions(for videoID: String) async throws -> [AudioStreamOption] {
        if let bundle = try? await PipedClient.streams(for: videoID), !bundle.audio.isEmpty {
            return bundle.audio
        }
        if let bundle = try? await InvidiousClient.streams(for: videoID), !bundle.audio.isEmpty {
            return bundle.audio
        }
        throw YouTubeError.everythingDown("nessuna sorgente ha restituito l'audio")
    }

    static func videoOptions(for videoID: String) async throws -> [VideoStreamOption] {
        if let bundle = try? await PipedClient.streams(for: videoID), !bundle.video.isEmpty {
            return bundle.video
        }
        if let bundle = try? await InvidiousClient.streams(for: videoID), !bundle.video.isEmpty {
            return bundle.video
        }
        throw YouTubeError.everythingDown("nessuna sorgente ha restituito il video")
    }

    private static func short(_ base: String) -> String {
        base.replacingOccurrences(of: "https://", with: "")
    }
}
