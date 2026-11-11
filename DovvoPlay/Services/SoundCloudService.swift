import Foundation

public class SoundCloudService {
    public static let shared = SoundCloudService()
    private init() {}

    public func search(query: String) async -> [SoundCloudTrack] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }

        // 1. Direct SoundCloud link
        if clean.contains("soundcloud.com/") {
            guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let oembedUrl = URL(string: "https://soundcloud.com/oembed?url=\(encoded)&format=json") else { return [] }

            if let (data, response) = try? await URLSession.shared.data(from: oembedUrl),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let title = json["title"] as? String ?? "SoundCloud Track"
                let author = json["author_name"] as? String ?? "SoundCloud"
                let thumb = json["thumbnail_url"] as? String ?? ""
                return [
                    SoundCloudTrack(
                        id: clean,
                        title: title,
                        author: author,
                        thumbnailUrl: thumb,
                        url: clean
                    )
                ]
            }
        }

        // 2. Query SoundCloud public search queries endpoint
        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://api-widget.soundcloud.com/search/queries?q=\(encoded)&client_id=LBCcHmRb8hHbd612gBtMc3usBi2DitLl&limit=15") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: searchUrl)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["collection"] as? [[String: Any]] else { return [] }

            return list.compactMap { item in
                let title = item["output"] as? String ?? clean
                let q = item["query"] as? String ?? title
                return SoundCloudTrack(
                    id: "sc_\(q)",
                    title: title,
                    author: "SoundCloud Creator",
                    thumbnailUrl: "https://a-v2.sndcdn.com/assets/images/sc-icons/ios-a62dfc8f.png",
                    url: "https://soundcloud.com/search?q=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                )
            }
        } catch {
            return []
        }
    }
}
