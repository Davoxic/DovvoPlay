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
    /// SoundCloud: la transcodifica da cui ricavare lo stream. YouTube: l'id del video.
    var resolveHint: String?
    /// SoundCloud: la transcodifica progressiva, l'unica scaricabile come file.
    var downloadHint: String? = nil
    /// Anteprima da 30 secondi riservata agli abbonati: inutile in un player.
    var isPreviewOnly: Bool = false
    /// SoundCloud: senza questo token la richiesta dello stream viene rifiutata.
    var trackAuthorization: String? = nil
    /// Solo flussi protetti con FairPlay: iOS non li può riprodurre.
    var isProtected: Bool = false

    var durationText: String { Track.timeString(duration) }

    /// Nome senza estensione con cui finisce in libreria.
    var baseName: String {
        var base = artist.isEmpty ? title : "\(artist) - \(title)"
        base = base.replacingOccurrences(of: "/", with: "-")
        base = base.replacingOccurrences(of: ":", with: "-")
        base = base.replacingOccurrences(of: "\\", with: "-")
        base = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "brano" }
        if base.count > 150 { base = String(base.prefix(150)) }
        return base
    }

    func fileName(ext: String) -> String { "\(baseName).\(ext)" }

    /// Nome di default: mp3 per SoundCloud, m4a per YouTube.
    var fileName: String {
        fileName(ext: source == .soundcloud ? "mp3" : "m4a")
    }

    /// Se il brano è già stato scaricato, il file su disco.
    var localFile: URL? {
        let fm = FileManager.default
        for ext in ["mp3", "m4a", "aac", "wav", "flac", "m4b"] {
            let candidate = LibraryPaths.musicDirectory.appendingPathComponent("\(baseName).\(ext)")
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    var isDownloaded: Bool { localFile != nil }
}
