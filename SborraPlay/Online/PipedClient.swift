import Foundation

/// Un flusso audio proposto da Piped.
struct AudioStreamOption: Hashable {
    let url: URL
    let bitrateKbps: Int
    let mimeType: String
    let codec: String
    let sizeBytes: Int64

    /// Solo l'AAC in contenitore mp4 è riproducibile da AVPlayer:
    /// gli stream Opus di YouTube stanno dentro WebM, che iOS non apre.
    var isPlayable: Bool {
        mimeType.contains("mp4") || mimeType.contains("m4a") || codec.hasPrefix("mp4a")
    }

    var fileExtension: String { isPlayable ? "m4a" : "webm" }

    var label: String {
        let size = sizeBytes > 0
            ? " · " + ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
            : ""
        return "\(bitrateKbps) kbps\(size)"
    }
}

struct VideoStreamOption: Hashable {
    let url: URL
    let quality: String
    let mimeType: String
    let sizeBytes: Int64

    var label: String {
        let size = sizeBytes > 0
            ? " · " + ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
            : ""
        return "\(quality)\(size)"
    }
}

struct StreamBundle {
    var title: String = ""
    var uploader: String = ""
    var duration: Double = 0
    var thumbnail: URL?
    var audio: [AudioStreamOption] = []
    var video: [VideoStreamOption] = []
}

/// Client per le istanze Piped: ricerca e stream di YouTube senza PC di mezzo.
enum PipedClient {

    enum PipedError: LocalizedError {
        case allInstancesDown
        case noAudio
        case badResponse

        var errorDescription: String? {
            switch self {
            case .allInstancesDown:
                return "Nessuna istanza Piped raggiungibile. Provane un'altra in Impostazioni, o usa il ponte sul PC."
            case .noAudio:
                return "Per questo video non c'è una traccia audio compatibile con iOS"
            case .badResponse:
                return "Risposta inattesa dall'istanza Piped"
            }
        }
    }

    /// Dalla lista ufficiale delle istanze pubbliche. Modificabile in Impostazioni.
    static let defaultInstances = [
        "https://pipedapi.kavin.rocks",
        "https://pipedapi.adminforge.de",
        "https://api.piped.yt",
        "https://pipedapi.drgns.space",
        "https://pipedapi.leptons.xyz",
        "https://api.piped.private.coffee",
        "https://pipedapi.ducks.party",
        "https://pipedapi.reallyaweso.me"
    ]

    /// Istanza scelta a mano, se c'è: viene provata per prima.
    static var preferredInstance: String? {
        get {
            let raw = UserDefaults.standard.string(forKey: "pipedInstance") ?? ""
            return raw.isEmpty ? nil : raw
        }
        set {
            let cleaned = (newValue ?? "").trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            UserDefaults.standard.set(cleaned, forKey: "pipedInstance")
            working = nil
        }
    }

    /// Ultima istanza che ha risposto: la riproviamo per prima.
    private static var working: String?

    static var instanceList: [String] {
        var list: [String] = []
        if let working { list.append(working) }
        if let preferred = preferredInstance { list.append(preferred) }
        list.append(contentsOf: fetchedInstances)
        list.append(contentsOf: defaultInstances)
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    static var activeInstance: String { working ?? preferredInstance ?? defaultInstances[0] }

    /// Da chiamare quando l'utente cambia istanza a mano.
    static func resetInstanceCache() { working = nil }

    /// Istanze lette dalla lista ufficiale, che cambia spesso: così l'app si
    /// aggiorna da sola invece di restare ferma su indirizzi morti.
    private static var fetchedInstances: [String] = []
    private static var lastFetch: Date?

    static func refreshInstanceList() async {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 6 * 3600 { return }
        let source = "https://raw.githubusercontent.com/TeamPiped/documentation/main/content/docs/public-instances/index.md"
        guard let url = URL(string: source),
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else { return }

        var found: [String] = []
        for line in text.components(separatedBy: .newlines) where line.hasPrefix("|") {
            let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            for cell in cells where cell.hasPrefix("https://") && !cell.contains(" ") {
                found.append(cell.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            }
        }
        var seen = Set<String>()
        let unique = found.filter { seen.insert($0).inserted }
        if unique.count >= 3 {
            fetchedInstances = unique
            lastFetch = Date()
        }
    }

    /// Prova un'istanza con una ricerca breve.
    static func test(_ base: String) async -> Bool {
        let cleaned = base.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var comps = URLComponents(string: cleaned + "/search") else { return false }
        comps.queryItems = [URLQueryItem(name: "q", value: "test"),
                            URLQueryItem(name: "filter", value: "music_songs")]
        guard let url = comps.url else { return false }
        guard let (_, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 9
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - chiamate con failover

    /// Le istanze pubbliche sono spesso lente o bloccate da YouTube: invece di
    /// provarle in fila (e far aspettare un minuto), le interroghiamo tutte
    /// insieme e teniamo la prima che risponde.
    private static func get(path: String, query: [URLQueryItem]) async throws -> Any {
        let bases = Array(instanceList.prefix(6))
        guard !bases.isEmpty else { throw PipedError.allInstancesDown }

        let winner: (data: Data, base: String)? = await withTaskGroup(
            of: (Data, String)?.self
        ) { group in
            for base in bases {
                group.addTask {
                    guard var comps = URLComponents(string: base + path) else { return nil }
                    if !query.isEmpty { comps.queryItems = query }
                    guard let url = comps.url else { return nil }
                    guard let (data, response) = try? await session.data(from: url),
                          let http = response as? HTTPURLResponse,
                          http.statusCode == 200,
                          data.count > 2 else { return nil }
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

        guard let winner else { throw PipedError.allInstancesDown }
        working = winner.base
        guard let json = try? JSONSerialization.jsonObject(with: winner.data) else {
            throw PipedError.badResponse
        }
        return json
    }

    /// Interroga una singola istanza, senza gara: serve per provarle a una a una
    /// quando una risponde ma i suoi URL audio vengono poi rifiutati.
    static func fetchJSON(base: String, path: String, query: [URLQueryItem] = []) async throws -> Any {
        guard var comps = URLComponents(string: base + path) else { throw PipedError.badResponse }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw PipedError.badResponse }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PipedError.badResponse
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw PipedError.badResponse
        }
        return json
    }

    // MARK: - diagnostica

    struct InstanceReport: Identifiable {
        let id = UUID()
        let base: String
        let ok: Bool
        let millis: Int
    }

    /// Prova tutte le istanze e dice quali rispondono: serve a capire se il
    /// problema è YouTube, la rete o l'app.
    static func probeAll() async -> [InstanceReport] {
        await withTaskGroup(of: InstanceReport.self) { group in
            for base in instanceList {
                group.addTask {
                    let start = Date()
                    var comps = URLComponents(string: base + "/search")
                    comps?.queryItems = [URLQueryItem(name: "q", value: "music"),
                                         URLQueryItem(name: "filter", value: "music_songs")]
                    guard let url = comps?.url else {
                        return InstanceReport(base: base, ok: false, millis: 0)
                    }
                    let response = try? await session.data(from: url)
                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                    let code = (response?.1 as? HTTPURLResponse)?.statusCode ?? 0
                    let hasItems: Bool
                    if let data = response?.0,
                       let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let items = root["items"] as? [[String: Any]] {
                        hasItems = !items.isEmpty
                    } else {
                        hasItems = false
                    }
                    return InstanceReport(base: base, ok: code == 200 && hasItems, millis: elapsed)
                }
            }
            var out: [InstanceReport] = []
            for await report in group { out.append(report) }
            return out.sorted { a, b in
                if a.ok != b.ok { return a.ok }
                return a.millis < b.millis
            }
        }
    }

    // MARK: - ricerca

    static func search(_ query: String, limit: Int = 25) async throws -> [OnlineTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results = try await runSearch(trimmed, filter: "music_songs")
        if results.isEmpty {
            results = try await runSearch(trimmed, filter: "videos")
        }
        return Array(results.prefix(limit))
    }

    private static func runSearch(_ query: String, filter: String) async throws -> [OnlineTrack] {
        let json = try await get(path: "/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "filter", value: filter)
        ])
        guard let root = json as? [String: Any],
              let items = root["items"] as? [[String: Any]] else {
            throw PipedError.badResponse
        }
        return items.compactMap(parseItem)
    }

    private static func parseItem(_ item: [String: Any]) -> OnlineTrack? {
        guard let title = item["title"] as? String else { return nil }
        guard let path = item["url"] as? String else { return nil }
        let videoID: String
        if let range = path.range(of: "v=") {
            videoID = String(path[range.upperBound...]).components(separatedBy: "&").first ?? ""
        } else {
            videoID = (path as NSString).lastPathComponent
        }
        guard !videoID.isEmpty else { return nil }

        let duration = (item["duration"] as? Double) ?? 0
        guard duration >= 0 else { return nil }

        return OnlineTrack(id: "yt-\(videoID)",
                           source: .youtube,
                           title: title,
                           artist: (item["uploaderName"] as? String) ?? "",
                           duration: duration,
                           artworkURL: URL(string: (item["thumbnail"] as? String) ?? ""),
                           pageURL: URL(string: "https://www.youtube.com/watch?v=\(videoID)"),
                           resolveHint: videoID)
    }

    // MARK: - stream

    static func streams(for videoID: String) async throws -> StreamBundle {
        let json = try await get(path: "/streams/\(videoID)", query: [])
        return parseStreams(json)
    }

    static func streams(for videoID: String, base: String) async throws -> StreamBundle {
        let json = try await fetchJSON(base: base, path: "/streams/\(videoID)")
        return parseStreams(json)
    }

    static func parseStreams(_ json: Any) -> StreamBundle {
        var bundle = StreamBundle()
        guard let root = json as? [String: Any] else { return bundle }

        bundle.title = (root["title"] as? String) ?? ""
        bundle.uploader = (root["uploader"] as? String) ?? ""
        bundle.duration = (root["duration"] as? Double) ?? 0
        bundle.thumbnail = URL(string: (root["thumbnailUrl"] as? String) ?? "")

        for raw in (root["audioStreams"] as? [[String: Any]]) ?? [] {
            guard let link = raw["url"] as? String, let url = URL(string: link) else { continue }
            bundle.audio.append(AudioStreamOption(
                url: url,
                bitrateKbps: normalizeBitrate(raw["bitrate"]),
                mimeType: (raw["mimeType"] as? String) ?? "",
                codec: (raw["codec"] as? String) ?? "",
                sizeBytes: Int64((raw["contentLength"] as? Double) ?? 0)
            ))
        }
        for raw in (root["videoStreams"] as? [[String: Any]]) ?? [] {
            guard let link = raw["url"] as? String, let url = URL(string: link) else { continue }
            if (raw["videoOnly"] as? Bool) == true { continue }
            bundle.video.append(VideoStreamOption(
                url: url,
                quality: (raw["quality"] as? String) ?? "?",
                mimeType: (raw["mimeType"] as? String) ?? "",
                sizeBytes: Int64((raw["contentLength"] as? Double) ?? 0)
            ))
        }
        return bundle
    }

    private static func normalizeBitrate(_ raw: Any?) -> Int {
        let value = (raw as? Double) ?? Double((raw as? Int) ?? 0)
        guard value > 0 else { return 0 }
        return value > 2000 ? Int(value / 1000) : Int(value)
    }

    // MARK: - scelta della qualità

    /// Sceglie il flusso audio secondo la qualità richiesta.
    /// Vengono considerati solo i flussi riproducibili da iOS (AAC in mp4).
    static func pick(_ options: [AudioStreamOption], quality: StreamQuality) -> AudioStreamOption? {
        let playable = options.filter { $0.isPlayable && $0.bitrateKbps > 0 }
        let pool = playable.isEmpty ? options.filter({ $0.isPlayable }) : playable
        guard !pool.isEmpty else { return nil }

        switch quality.resolved {
        case .high, .auto:
            return pool.max { $0.bitrateKbps < $1.bitrateKbps }
        case .saver:
            // il più basso che resti ascoltabile: sotto i 40 kbps la musica si sfalda
            let decent = pool.filter { $0.bitrateKbps >= 40 }
            if let best = decent.min(by: { $0.bitrateKbps < $1.bitrateKbps }) { return best }
            return pool.min { $0.bitrateKbps < $1.bitrateKbps }
        }
    }

    static func bestVideo(_ options: [VideoStreamOption]) -> VideoStreamOption? {
        options.first
    }
}
