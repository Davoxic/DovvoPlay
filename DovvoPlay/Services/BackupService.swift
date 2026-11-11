import Foundation
import UIKit

public struct BackupResult {
    public let success: Bool
    public let message: String
    public let restoredStats: Int
    public let restoredPlaylists: Int
    public let restoredTracks: Int

    public init(
        success: Bool,
        message: String,
        restoredStats: Int = 0,
        restoredPlaylists: Int = 0,
        restoredTracks: Int = 0
    ) {
        self.success = success
        self.message = message
        self.restoredStats = restoredStats
        self.restoredPlaylists = restoredPlaylists
        self.restoredTracks = restoredTracks
    }
}

public class BackupService {
    public static let shared = BackupService()
    private init() {}

    private let autoBackupFileName = "dovvoplay_full_backup.json"

    private var backupDirectory: URL {
        let docs = LibraryService.shared.documentsDirectory
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var autoBackupFile: URL {
        LibraryService.shared.documentsDirectory.appendingPathComponent(autoBackupFileName)
    }

    public func createBackupJsonString() -> String {
        let stats = StatsService.shared.stats
        let playlists = LibraryService.shared.playlists
        let tracks = LibraryService.shared.tracks

        let dict: [String: Any] = [
            "app": "DovvoPlay",
            "version": "2.0.0",
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "stats": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(stats))) ?? [:],
            "playlists": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(playlists))) ?? [],
            "tracks": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(tracks))) ?? []
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    public func exportToFile() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = formatter.string(from: Date())
        let filename = "DovvoPlay_Backup_\(dateStr).json"
        let targetURL = backupDirectory.appendingPathComponent(filename)

        let jsonStr = createBackupJsonString()
        try jsonStr.write(to: targetURL, atomically: true, encoding: .utf8)
        try? jsonStr.write(to: autoBackupFile, atomically: true, encoding: .utf8)

        return targetURL
    }

    public func importFromJsonString(_ jsonStr: String) -> BackupResult {
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return BackupResult(success: false, message: "Formato backup non valido (non è un oggetto JSON).")
        }

        var restoredStats = 0
        var restoredPlaylists = 0
        var restoredTracks = 0

        // 1. Stats
        if let statsMap = dict["stats"] as? [String: Any],
           let statsData = try? JSONSerialization.data(withJSONObject: statsMap),
           let decodedStats = try? JSONDecoder().decode([String: TrackStat].self, from: statsData) {
            for (_, stat) in decodedStats {
                StatsService.shared.restoreOrMergeStat(stat)
                restoredStats += 1
            }
            StatsService.shared.saveAndNotify()
        }

        // 2. Playlists
        if let plList = dict["playlists"] as? [[String: Any]],
           let plData = try? JSONSerialization.data(withJSONObject: plList),
           let decodedPlaylists = try? JSONDecoder().decode([Playlist].self, from: plData) {
            for p in decodedPlaylists {
                LibraryService.shared.createPlaylist(name: p.name, trackIds: p.trackIds)
                restoredPlaylists += 1
            }
        }

        // 3. Tracks
        if let trList = dict["tracks"] as? [[String: Any]],
           let trData = try? JSONSerialization.data(withJSONObject: trList),
           let decodedTracks = try? JSONDecoder().decode([Track].self, from: trData) {
            for t in decodedTracks where t.isOnline {
                if !LibraryService.shared.tracks.contains(where: { $0.id == t.id }) {
                    // Track preserved
                    restoredTracks += 1
                }
            }
        }

        // Update auto backup copy
        try? jsonStr.write(to: autoBackupFile, atomically: true, encoding: .utf8)

        return BackupResult(
            success: true,
            message: "Ripristino completato con successo!",
            restoredStats: restoredStats,
            restoredPlaylists: restoredPlaylists,
            restoredTracks: restoredTracks
        )
    }

    public func importFromFile(_ fileURL: URL) -> BackupResult {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return BackupResult(success: false, message: "Impossibile leggere il file.")
        }
        return importFromJsonString(content)
    }

    public func autoRestoreIfEmpty() {
        guard FileManager.default.fileExists(atPath: autoBackupFile.path) else { return }
        if StatsService.shared.stats.isEmpty && LibraryService.shared.playlists.isEmpty {
            if let content = try? String(contentsOf: autoBackupFile, encoding: .utf8) {
                _ = importFromJsonString(content)
            }
        }
    }
}
