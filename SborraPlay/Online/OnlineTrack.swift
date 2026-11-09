import Foundation

enum OnlineSource: String, Codable, CaseIterable, Identifiable {
    case soundcloud
    case youtube

    var id: String { rawValue }
    var label: String {
        switch self {
        case .soundcloud: return "SoundCloud"
        case .youtube: return "YouTube"
        }
    }
    var symbol: String {
        switch self {
        case .soundcloud: return "cloud.fill"
        case .youtube: return "play.rectangle.fill"
        }
    }
}

/// Un risultato di ricerca online, non ancora scaricato.
struct OnlineTrack: Identifiable, Hashable {
    var id: String
    var source: OnlineSource
    var title: String
    var artist: String
    var duration: Double
    var artworkURL: URL?
    var pageURL: URL?
    /// Per SoundCloud: l'endpoint da cui ricavare il file. Per YouTube lo chiede il ponte.
    var resolveHint: String?

    var durationText: String { Track.timeString(duration) }

    /// Nome con cui finirà in libreria.
    var fileName: String {
        var base = artist.isEmpty ? title : "\(artist) - \(title)"
        base = base.replacingOccurrences(of: "/", with: "-")
        base = base.replacingOccurrences(of: ":", with: "-")
        base = base.replacingOccurrences(of: "\\", with: "-")
        base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "brano" }
        if base.count > 150 { base = String(base.prefix(150)) }
        return base + ".mp3"
    }
}
