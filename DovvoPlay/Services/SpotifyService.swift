import Foundation

public class SpotifyService {
    public static let shared = SpotifyService()
    private init() {}

    public func getTrackInfoFromUrl(_ urlStr: String) async -> SpotifyItem? {
        guard let encoded = urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedUrl = URL(string: "https://open.spotify.com/oembed?url=\(encoded)") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: oembedUrl)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let fullTitle = json["title"] as? String ?? "Spotify Track"
            let thumb = json["thumbnail_url"] as? String ?? ""
            let author = json["author_name"] as? String ?? "Spotify"

            var title = fullTitle
            var artist = author
            if fullTitle.contains(" - ") {
                let parts = fullTitle.components(separatedBy: " - ")
                title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                artist = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return SpotifyItem(
                id: urlStr,
                title: title,
                artist: artist,
                thumbnailUrl: thumb,
                url: urlStr
            )
        } catch {
            return nil
        }
    }

    public func parseSpotifyPlaylist(_ playlistUrl: String) async -> SpotifyPlaylistInfo? {
        guard let encoded = playlistUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedUrl = URL(string: "https://open.spotify.com/oembed?url=\(encoded)") else { return nil }

        var plTitle = "Playlist Spotify"
        var plAuthor = "Spotify User"
        var plThumb = ""

        if let (data, response) = try? await URLSession.shared.data(from: oembedUrl),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            plTitle = json["title"] as? String ?? "Playlist Spotify"
            plAuthor = json["author_name"] as? String ?? "Spotify"
            plThumb = json["thumbnail_url"] as? String ?? ""
        }

        var tracks: [SpotifyItem] = []
        let embedUrlStr = playlistUrl.replacingOccurrences(of: "open.spotify.com/playlist/", with: "open.spotify.com/embed/playlist/")
        if let embedUrl = URL(string: embedUrlStr) {
            var req = URLRequest(url: embedUrl)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await URLSession.shared.data(for: req),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let html = String(data: data, encoding: .utf8) {

                if let startRange = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
                   let endRange = html[startRange.upperBound...].range(of: "</script>") {
                    let jsonSub = String(html[startRange.upperBound..<endRange.lowerBound])
                    if let jsonData = jsonSub.data(using: .utf8),
                       let nextJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let props = nextJson["props"] as? [String: Any],
                       let pageProps = props["pageProps"] as? [String: Any],
                       let state = pageProps["state"] as? [String: Any],
                       let entityData = state["data"] as? [String: Any],
                       let entity = entityData["entity"] as? [String: Any],
                       let rawTracks = entity["trackList"] as? [[String: Any]] {

                        for t in rawTracks {
                            let title = t["title"] as? String ?? ""
                            let subtitle = t["subtitle"] as? String ?? ""
                            if !title.isEmpty {
                                tracks.append(SpotifyItem(
                                    id: (t["uri"] as? String) ?? "\(title)-\(subtitle)",
                                    title: title,
                                    artist: !subtitle.isEmpty ? subtitle : plAuthor,
                                    thumbnailUrl: plThumb,
                                    url: playlistUrl
                                ))
                            }
                        }
                    }
                }
            }
        }

        if tracks.isEmpty {
            if let single = await getTrackInfoFromUrl(playlistUrl) {
                tracks.append(single)
            }
        }

        return SpotifyPlaylistInfo(title: plTitle, author: plAuthor, thumbnailUrl: plThumb, tracks: tracks)
    }

    public func search(query: String) async -> [SpotifyItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }

        if clean.contains("open.spotify.com/") {
            if let item = await getTrackInfoFromUrl(clean) {
                return [item]
            }
        }

        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=15") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: searchUrl)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return [] }

            return results.compactMap { r in
                let title = r["trackName"] as? String ?? "Brano"
                let artist = r["artistName"] as? String ?? "Artista"
                let rawThumb = r["artworkUrl100"] as? String ?? ""
                let thumb = rawThumb.replacingOccurrences(of: "100x100", with: "600x600")
                let durMs = r["trackTimeMillis"] as? Int ?? 0
                let trackId = r["trackId"] != nil ? "\(r["trackId"]!)" : UUID().uuidString
                let trackUrl = r["trackViewUrl"] as? String ?? ""

                return SpotifyItem(
                    id: "sp_\(trackId)",
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumb,
                    url: trackUrl,
                    duration: TimeInterval(durMs) / 1000.0
                )
            }
        } catch {
            return []
        }
    }
}
