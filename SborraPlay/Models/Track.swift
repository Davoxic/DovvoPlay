import Foundation

/// Un brano presente nella cartella Music/ dell'app.
/// `id` è il percorso relativo a Music/ (es. "Artista - Titolo.mp3").
struct Track: Identifiable, Codable, Hashable {
    var id: String
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var albumArtist: String = ""
    var genre: String = ""
    var year: Int = 0
    var trackNumber: Int = 0
    var discNumber: Int = 0
    var duration: Double = 0
    var fileSize: Int64 = 0
    var modified: Date = .distantPast
    var dateAdded: Date = Date()
    var artworkID: String? = nil

    var fileName: String { id }
    var url: URL { LibraryPaths.musicDirectory.appendingPathComponent(id) }

    var displayTitle: String { title.isEmpty ? (id as NSString).deletingPathExtension : title }
    var displayArtist: String { artist.isEmpty ? "Artista sconosciuto" : artist }
    var displayAlbum: String { album.isEmpty ? "Album sconosciuto" : album }
    var effectiveAlbumArtist: String { albumArtist.isEmpty ? displayArtist : albumArtist }
    var durationText: String { Track.timeString(duration) }

    /// Chiave usata per raggruppare i brani in album.
    var albumKey: String { "\(effectiveAlbumArtist.lowercased())|\(displayAlbum.lowercased())" }

    static func timeString(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "--:--" }
        let total = Int(t.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

/// Un album, ricavato raggruppando i brani.
struct AlbumGroup: Identifiable, Hashable {
    var id: String
    var title: String
    var artist: String
    var tracks: [Track]
    var artworkID: String? { tracks.first(where: { $0.artworkID != nil })?.artworkID }
    var totalDuration: Double { tracks.reduce(0) { $0 + $1.duration } }
}

/// Un artista, ricavato raggruppando i brani.
struct ArtistGroup: Identifiable, Hashable {
    var id: String
    var name: String
    var tracks: [Track]
    var albumCount: Int
    var artworkID: String? { tracks.first(where: { $0.artworkID != nil })?.artworkID }
}
