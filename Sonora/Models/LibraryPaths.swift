import Foundation

enum LibraryPaths {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var musicDirectory: URL {
        documents.appendingPathComponent("Music", isDirectory: true)
    }
    static var inboxDirectory: URL {
        documents.appendingPathComponent("Inbox", isDirectory: true)
    }
    static var artworkDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("Artwork", isDirectory: true)
    }
    static var indexFile: URL { documents.appendingPathComponent("library.json") }
    static var playlistsFile: URL { documents.appendingPathComponent("playlists.json") }

    /// Estensioni gestite da AVAudioPlayer su iOS.
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "mp4", "aac", "adts", "wav", "wave",
        "aif", "aiff", "aifc", "caf", "flac", "alac", "au", "snd", "mp2", "mpa"
    ]

    static let playlistExtensions: Set<String> = ["m3u", "m3u8"]

    static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [musicDirectory, artworkDirectory] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    /// Ripulisce un nome file ricevuto dalla rete: niente path traversal, niente separatori.
    static func sanitize(fileName raw: String) -> String {
        var name = (raw as NSString).lastPathComponent
        name = name.replacingOccurrences(of: "/", with: "-")
        name = name.replacingOccurrences(of: "\\", with: "-")
        name = name.replacingOccurrences(of: "\0", with: "")
        while name.hasPrefix(".") { name.removeFirst() }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "brano-\(Int(Date().timeIntervalSince1970)).mp3" }
        if name.count > 180 {
            let ext = (name as NSString).pathExtension
            let base = String((name as NSString).deletingPathExtension.prefix(160))
            name = ext.isEmpty ? base : "\(base).\(ext)"
        }
        return name
    }

    /// Restituisce una destinazione libera dentro Music/, aggiungendo " (2)", " (3)"… se serve.
    static func uniqueDestination(for fileName: String) -> URL {
        ensureDirectories()
        let fm = FileManager.default
        let clean = sanitize(fileName: fileName)
        var candidate = musicDirectory.appendingPathComponent(clean)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let ext = (clean as NSString).pathExtension
        let base = (clean as NSString).deletingPathExtension
        var i = 2
        while fm.fileExists(atPath: candidate.path) && i < 1000 {
            let name = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
            candidate = musicDirectory.appendingPathComponent(name)
            i += 1
        }
        return candidate
    }
}
