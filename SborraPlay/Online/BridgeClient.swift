import Foundation

/// Parla con il "ponte" che gira sul computer (sborraplay-dl serve).
/// Serve per YouTube: l'estrazione la fa yt-dlp, che su iOS non può girare.
/// L'indirizzo del PC non si configura a mano: è il ponte stesso ad annunciarsi
/// all'app con POST /api/bridge appena parte.
enum BridgeClient {

    enum BridgeError: LocalizedError {
        case notConfigured
        case unreachable
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Nessun computer collegato. Sul PC apri SborraPlay e scegli \"Avvia il ponte\"."
            case .unreachable:
                return "Il computer non risponde. Controlla che il ponte sia acceso e di essere sulla stessa rete."
            case .badResponse(let text):
                return text
            }
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        return URLSession(configuration: config)
    }()

    static var baseURL: URL? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "bridgeURL") else { return nil }
            return URL(string: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: "bridgeURL")
        }
    }

    static var isConfigured: Bool { baseURL != nil }

    private static func url(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard let base = baseURL,
              var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw BridgeError.notConfigured
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let final = comps.url else { throw BridgeError.notConfigured }
        return final
    }

    @discardableResult
    static func health() async -> Bool {
        guard let target = try? url("health") else { return false }
        guard let (_, response) = try? await session.data(from: target),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    static func search(_ query: String, limit: Int = 25) async throws -> [OnlineTrack] {
        let target = try url("search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ])
        let (data, response) = try await session.data(from: target)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.unreachable }
        guard http.statusCode == 200 else { throw BridgeError.badResponse("Il ponte ha risposto \(http.statusCode)") }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["results"] as? [[String: Any]] else {
            throw BridgeError.badResponse("Risposta del ponte non leggibile")
        }
        return items.compactMap { item in
            guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
            return OnlineTrack(id: "yt-\(id)",
                               source: .youtube,
                               title: title,
                               artist: (item["artist"] as? String) ?? "",
                               duration: (item["duration"] as? Double) ?? 0,
                               artworkURL: URL(string: (item["artwork"] as? String) ?? ""),
                               pageURL: URL(string: (item["url"] as? String) ?? ""),
                               resolveHint: id)
        }
    }

    /// Chiede a yt-dlp l'URL audio diretto: poi il telefono scarica dai server di
    /// Google senza far passare i dati dal PC.
    static func streamURL(for track: OnlineTrack) async throws -> URL {
        guard let hint = track.resolveHint else { throw BridgeError.badResponse("Brano senza riferimento") }
        let target = try url("stream", query: [URLQueryItem(name: "id", value: hint)])
        let (data, response) = try await session.data(from: target)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BridgeError.unreachable
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["url"] as? String, let final = URL(string: raw) else {
            throw BridgeError.badResponse("Il ponte non ha trovato l'audio")
        }
        return final
    }

    /// Chiede al PC di scaricare il brano in mp3, taggarlo e spedirlo al telefono.
    static func grab(_ track: OnlineTrack, callback: String?) async throws -> String {
        guard let hint = track.resolveHint else { throw BridgeError.badResponse("Brano senza riferimento") }
        let target = try url("grab")
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        var payload: [String: Any] = [
            "id": hint,
            "title": track.title,
            "artist": track.artist
        ]
        if let callback { payload["callback"] = callback }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.unreachable }
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard http.statusCode == 200, (root?["ok"] as? Bool) == true else {
            throw BridgeError.badResponse((root?["error"] as? String) ?? "Download non riuscito sul computer")
        }
        return (root?["file"] as? String) ?? track.fileName
    }
}
