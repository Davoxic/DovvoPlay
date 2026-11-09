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
            return "Nessuno stream audio compatibile (mp4a) trovato. L'AVPlayer non supporta questo formato."
        case .cipherNotSupported:
            return "Questo video richiede la decrittazione della firma, operazione non supportata."
        }
    }
}

/// Facciata su YouTube: prova Piped, poi Invidious, poi il ponte sul PC.
/// Tiene traccia di chi ha risposto, così l'errore dice qualcosa di utile.
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

    static func search(_ query: String, allowBridge: Bool) async throws -> [OnlineTrack] {
        if let viaPiped = try? await PipedClient.search(query), !viaPiped.isEmpty {
            lastBackend = "Piped (\(short(PipedClient.activeInstance)))"
            return viaPiped
        }
        if let viaInvidious = try? await InvidiousClient.search(query), !viaInvidious.isEmpty {
            lastBackend = "Invidious"
            return viaInvidious
        }
        if allowBridge, let viaBridge = try? await BridgeClient.search(query), !viaBridge.isEmpty {
            lastBackend = "ponte sul PC"
            return viaBridge
        }
        lastBackend = "nessuno"
        throw YouTubeError.everythingDown("né le istanze Piped né quelle Invidious hanno risposto")
    }

    /// Risolve l'audio usando direttamente le API InnerTube di YouTube (client iOS nativo).
    static func resolveAudio(videoID: String, quality: StreamQuality) async throws -> URL {
        let apiUrl = URL(string: "https://www.youtube.com/youtubei/v1/player")!
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Un user-agent fittizio ma credibile
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone14,3; U; CPU iOS 16_4_1 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        // Spacciandoci per client IOS nativo, YouTube tende a fornire URL diretti 
        // e non offuscati (evitiamo il JS parser).
        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "19.29.1",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone14,3",
                    "osName": "iOS",
                    "osVersion": "16.4.1",
                    "hl": "it", // Lingua
                    "gl": "IT"  // Regione
                ]
            ],
            "videoId": videoID
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(InnerTubeResponse.self, from: data)
        
        // 1. Controllo se il video è bloccato (es. limiti di età o copyright)
        if let status = response.playabilityStatus?.status, status != "OK" {
            let reason = response.playabilityStatus?.reason ?? "Motivo sconosciuto"
            throw YouTubeStreamError.unplayable(reason)
        }
        
        guard let streamingData = response.streamingData else {
            throw YouTubeStreamError.noAudioStreamFound
        }
        
        // 2. Controllo per le Live: se è una live, YouTube ci dà un URL m3u8 (HLS)
        // AVPlayer lo digerisce nativamente senza dover fare il parse dei chunk!
        if let hlsManifest = streamingData.hlsManifestUrl, let liveUrl = URL(string: hlsManifest) {
            lastBackend = "YouTube Diretto (Live)"
            return liveUrl
        }
        
        // 3. Uniamo tutti i formati disponibili
        let allFormats = (streamingData.formats ?? []) + (streamingData.adaptiveFormats ?? [])
        
        // 4. Filtriamo SOLO i formati audio che AVPlayer sa leggere (AAC in MP4/M4A)
        var audioFormats = allFormats.filter { format in
            let isMp4a = format.mimeType.contains("audio/mp4") || format.mimeType.contains("audio/x-m4a")
            return isMp4a
        }
        
        if audioFormats.isEmpty {
            throw YouTubeStreamError.noAudioStreamFound
        }
        
        // 5. Ordiniamo per bitrate (dal più basso al più alto)
        audioFormats.sort { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }
        
        let selectedFormat: Format
        
        // Adatta i "case" a quelli dell'enum StreamQuality (.saver / .high / .auto)
        switch quality.resolved {
        case .saver: // risparmio dati -> bitrate più basso
            selectedFormat = audioFormats.first! 
        default:   // high/auto -> bitrate più alto
            selectedFormat = audioFormats.last! 
        }
        
        // 6. Restituiamo l'URL diretto
        if let streamURLString = selectedFormat.url, let streamURL = URL(string: streamURLString) {
            lastBackend = "YouTube Diretto"
            return streamURL
        }
        
        // Se c'è solo signatureCipher/cipher, significherebbe che serve l'engine JS 
        // (molto raro chiedendo come client IOS, ma gestiamo l'errore per non far girare rotelle a vuoto)
        if selectedFormat.signatureCipher != nil || selectedFormat.cipher != nil {
            throw YouTubeStreamError.cipherNotSupported
        }
        
        throw YouTubeStreamError.noAudioStreamFound
    }

    /// La qualità richiesta per prima, poi le altre come riserva.
    private static func ranked(_ options: [AudioStreamOption], quality: StreamQuality) -> [AudioStreamOption] {
        let playable = options.filter { $0.isPlayable }
        guard !playable.isEmpty else { return [] }
        var ordered: [AudioStreamOption] = []
        if let first = PipedClient.pick(playable, quality: quality) { ordered.append(first) }
        let sorted = quality.resolved == .saver
            ? playable.sorted { $0.bitrateKbps < $1.bitrateKbps }
            : playable.sorted { $0.bitrateKbps > $1.bitrateKbps }
        for option in sorted where !ordered.contains(option) { ordered.append(option) }
        return ordered
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

// MARK: - Strutture private per JSON InnerTube

private struct InnerTubeResponse: Decodable {
    let streamingData: StreamingData?
    let playabilityStatus: PlayabilityStatus?
}

private struct PlayabilityStatus: Decodable {
    let status: String
    let reason: String?
}

private struct StreamingData: Decodable {
    let formats: [Format]?
    let adaptiveFormats: [Format]?
    let hlsManifestUrl: String? // Fondamentale per i flussi Live
}

private struct Format: Decodable {
    let itag: Int
    let url: String?
    let signatureCipher: String?
    let cipher: String?
    let mimeType: String
    let bitrate: Int?
}
