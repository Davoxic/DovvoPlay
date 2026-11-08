import Foundation
import UIKit

/// Contenuto di un file di backup .sborraplay.json
struct BackupFile: Codable {
    var format: Int = 1
    var app: String = "SborraPlay"
    var appVersion: String = ""
    var createdAt: Date = Date()
    var deviceName: String = ""
    var playlists: [Playlist] = []
    /// Indice dei brani: serve a sapere cosa manca dopo un ripristino.
    var tracks: [Track] = []
    /// coverID → JPEG in base64
    var covers: [String: String] = [:]
    var settings: [String: String] = [:]

    var summary: String {
        let n = playlists.count
        let c = covers.count
        return "\(n) playlist · \(tracks.count) brani · \(c) copertine"
    }
}

enum BackupManager {

    static var backupsDirectory: URL {
        LibraryPaths.documents.appendingPathComponent("Backups", isDirectory: true)
    }

    static func ensureDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: backupsDirectory.path) {
            try? fm.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - creazione

    static func make(playlists: [Playlist], tracks: [Track], settings: [String: String]) -> BackupFile {
        var backup = BackupFile()
        backup.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        backup.deviceName = UIDevice.current.name
        backup.playlists = playlists
        backup.tracks = tracks
        backup.settings = settings

        for playlist in playlists {
            guard let id = playlist.coverID, backup.covers[id] == nil else { continue }
            if let data = try? Data(contentsOf: CoverStore.url(for: id)) {
                backup.covers[id] = data.base64EncodedString()
            }
        }
        return backup
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupFile.self, from: data)
    }

    static func fileName(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "SborraPlay-\(f.string(from: date)).sborraplay.json"
    }

    /// Scrive il backup in una cartella temporanea, pronto per essere condiviso.
    static func writeTemporary(_ backup: BackupFile) throws -> URL {
        let data = try encode(backup)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName())
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - copie automatiche

    /// Salva una copia in Documents/Backups una volta al giorno, tenendo le ultime 5.
    /// Documents è visibile dall'app File, quindi le copie si possono tirare fuori a mano.
    @discardableResult
    static func autoBackup(_ backup: BackupFile, keep: Int = 5) -> URL? {
        ensureDirectory()
        let url = backupsDirectory.appendingPathComponent(fileName())
        guard let data = try? encode(backup) else { return nil }
        try? data.write(to: url, options: .atomic)
        prune(keep: keep)
        return url
    }

    static func listBackups() -> [URL] {
        ensureDirectory()
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: backupsDirectory,
                                                 includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return items
            .filter { $0.lastPathComponent.hasSuffix(".json") }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da > db
            }
    }

    private static func prune(keep: Int) {
        let all = listBackups()
        guard all.count > keep else { return }
        for url in all.dropFirst(keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Rimette su disco le copertine contenute nel backup.
    @discardableResult
    static func restoreCovers(from backup: BackupFile) -> Int {
        LibraryPaths.ensureDirectories()
        var written = 0
        for (id, encoded) in backup.covers {
            guard let data = Data(base64Encoded: encoded) else { continue }
            if (try? data.write(to: CoverStore.url(for: id), options: .atomic)) != nil {
                written += 1
            }
        }
        return written
    }
}
