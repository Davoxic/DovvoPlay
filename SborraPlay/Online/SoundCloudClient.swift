import Foundation

/// Ricerca e riproduzione da SoundCloud senza passare dal PC.
/// SoundCloud non pubblica più chiavi API: il client_id si ricava dagli script
/// del sito, come fa il player web. Se cambia, lo rileggiamo.
enum SoundCloudClient {

    enum ClientError: LocalizedError {
        case noClientID
        case badResponse
        case noStream

        var errorDescription: String? {
            switch self {
            case .noClientID: return "SoundCloud non raggiungibile in questo momento"
            case .badResponse: return "Risposta inattesa da SoundCloud"
            case .noStream: return "Questo brano non è riproducibile fuori da SoundCloud"
            }
        }
    }

    private static var cachedID: String?
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // MARK: - client id

    static func clientID(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh {
            if let cachedID { return cachedID }
            if let saved = UserDefaults.standard.string(forKey: "scClientID"), !saved.isEmpty {
                cachedID = saved
                return saved
            }
        }
        guard let home = URL(string: "https://soundcloud.com/discover") else { throw ClientError.noClientID }
        let (data, _) = try await session.data(from: home)
        guard let html = String(data: data, encoding: .utf8) else { throw ClientError.noClientID }

        // gli script del player contengono client_id:"..."
        var scripts: [String] = []
        var cursor = html.startIndex
        while let range = html.range(of: #"https://a-v2\.sndcdn\.com/assets/[^"']+\.js"#,
                                     options: .regularExpression,
                                     range: cursor..<html.endIndex) {
            scripts.append(String(html[range]))
            cursor = range.upperBound
        }

        for script in scripts.reversed() {
            guard let url = URL(string: script) else { continue }
            guard let (jsData, _) = try? await session.data(from: url),
                  let js = String(data: jsData, encoding: .utf8) else { continue }
            if let found = firstMatch(in: js, pattern: #"client_id\s*:\s*"([a-zA-Z0-9]{32})""#) {
                cachedID = found
                UserDefaults.standard.set(found, forKey: "scClientID")
                return found
            }
        }
        throw ClientError.noClientID
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - ricerca

    static func search(_ query: String, limit: Int = 30) async throws -> [OnlineTrack] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            return try await runSearch(trimmed, limit: limit, id: try await clientID())
        } catch {
            // il client_id può scadere: ne prendiamo uno nuovo e riproviamo una volta
            let fresh = try await clientID(forceRefresh: true)
            return try await runSearch(trimmed, limit: limit, id: fresh)
        }
    }

    private static func runSearch(_ query: String, limit: Int, id: String) async throws -> [OnlineTrack] {
        var comps = URLComponents(string: "https://api-v2.soundcloud.com/search/tracks")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "client_id", value: id),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "app_locale", value: "it")
        ]
        guard let url = comps.url else { throw ClientError.badResponse }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClientError.badResponse
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let collection = root["collection"] as? [[String: Any]] else {
            throw ClientError.badResponse
        }
        return collection.compactMap(parse)
    }

    private static func parse(_ item: [String: Any]) -> OnlineTrack? {
        guard let title = item["title"] as? String else { return nil }
        let user = item["user"] as? [String: Any]
        let artist = (user?["username"] as? String) ?? ""
        let millis = (item["duration"] as? Double) ?? (item["full_duration"] as? Double) ?? 0
        let identifier = String(describing: item["id"] ?? UUID().uuidString)

        var artwork: URL?
        if let raw = item["artwork_url"] as? String {
            artwork = URL(string: raw.replacingOccurrences(of: "-large", with: "-t500x500"))
        } else if let avatar = user?["avatar_url"] as? String {
            artwork = URL(string: avatar)
        }

        // transcodifica progressiva = un mp3 diretto, riproducibile e scaricabile
        var hint: String?
        if let media = item["media"] as? [String: Any],
           let transcodings = media["transcodings"] as? [[String: Any]] {
            for t in transcodings {
                let format = t["format"] as? [String: Any]
                let protocolName = (format?["protocol"] as? String) ?? ""
                if protocolName == "progressive", let link = t["url"] as? String {
                    hint = link
                    break
                }
            }
            if hint == nil, let first = transcodings.first, let link = first["url"] as? String {
                hint = link      // hls: AVPlayer lo riproduce comunque
            }
        }

        return OnlineTrack(id: "sc-\(identifier)",
                           source: .soundcloud,
                           title: title,
                           artist: artist,
                           duration: millis / 1000.0,
                           artworkURL: artwork,
                           pageURL: URL(string: (item["permalink_url"] as? String) ?? ""),
                           resolveHint: hint)
    }

    // MARK: - stream

    /// Trasforma la transcodifica in un URL riproducibile.
    static func streamURL(for track: OnlineTrack) async throws -> URL {
        guard let hint = track.resolveHint, var comps = URLComponents(string: hint) else {
            throw ClientError.noStream
        }
        let id = try await clientID()
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "client_id", value: id))
        comps.queryItems = items
        guard let url = comps.url else { throw ClientError.noStream }

        let (data, _) = try await session.data(from: url)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["url"] as? String,
              let final = URL(string: raw) else {
            throw ClientError.noStream
        }
        return final
    }
}
