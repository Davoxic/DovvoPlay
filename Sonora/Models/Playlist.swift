import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var trackIDs: [String] = []
    var createdAt: Date = Date()
    var source: String = "locale"   // "locale", "spotify", "m3u"

    var subtitle: String {
        let n = trackIDs.count
        return n == 1 ? "1 brano" : "\(n) brani"
    }
}
