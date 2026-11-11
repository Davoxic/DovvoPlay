import Foundation
import SwiftUI

public class LibraryService: ObservableObject {
    public static let shared = LibraryService()

    @Published public private(set) var tracks: [Track] = []
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var isLoading: Bool = false

    public var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public var musicDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("Music", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public var coversDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("Covers", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var libraryFile: URL {
        documentsDirectory.appendingPathComponent("library.json")
    }

    private var playlistsFile: URL {
        documentsDirectory.appendingPathComponent("playlists.json")
    }

    private init() {
        Task {
            await initService()
        }
    }

    @MainActor
    public func initService() async {
        isLoading = true
        loadSavedData()
        await scanLibrary()
        isLoading = false
    }

    private func loadSavedData() {
        if FileManager.default.fileExists(atPath: libraryFile.path),
           let data = try? Data(contentsOf: libraryFile) {
            if let jsonMap = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tracksArray = jsonMap["tracks"] as? [[String: Any]],
               let tracksData = try? JSONSerialization.data(withJSONObject: tracksArray),
               let loadedTracks = try? JSONDecoder().decode([Track].self, from: tracksData) {
                self.tracks = loadedTracks
            }
        }

        if FileManager.default.fileExists(atPath: playlistsFile.path),
           let data = try? Data(contentsOf: playlistsFile),
           let loadedPlaylists = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = loadedPlaylists
        }
    }

    public func scanLibrary() async {
        let validExts = Set(["mp3", "m4a", "aac", "wav", "flac", "aif", "aiff", "caf", "alac"])
        let musicDir = self.musicDirectory
        let coversDir = self.coversDirectory

        guard let enumerator = FileManager.default.enumerator(at: musicDir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return
        }

        var foundURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if validExts.contains(ext) {
                foundURLs.append(fileURL)
            }
        }

        let existingMap = Dictionary(uniqueKeysWithValues: tracks.compactMap { t -> (String, Track)? in
            guard let fp = t.filePath else { return nil }
            return (fp, t)
        })

        var newTracks: [Track] = []

        for fileURL in foundURLs {
            let path = fileURL.path
            let filename = fileURL.deletingPathExtension().lastPathComponent
            let existing = existingMap[path]

            // If already exists and has thumbnail, keep for speed
            if let existing = existing, let thumb = existing.thumbnailUrl, !thumb.isEmpty {
                newTracks.append(existing)
                continue
            }

            let meta = await MetadataService.shared.extractMetadata(fileURL: fileURL, coversDirectory: coversDir)
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

            let durationMs = meta.duration != nil ? Int(meta.duration! * 1000.0) : (existing?.durationMs ?? 0)
            let title = meta.title ?? (existing?.title ?? filename)
            let artist = meta.artist ?? (existing?.artist ?? "Artista sconosciuto")
            let album = meta.album ?? (existing?.album ?? "")
            let cover = meta.coverPath ?? existing?.thumbnailUrl
            let bpm = meta.bpm ?? existing?.bpm

            let track = Track(
                id: path,
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                filePath: path,
                isOnline: false,
                thumbnailUrl: cover,
                fileSize: fileSize,
                bpm: bpm
            )
            newTracks.append(track)
        }

        // Keep explicit online tracks
        for t in tracks where t.isOnline {
            if !newTracks.contains(where: { $0.id == t.id }) {
                newTracks.append(t)
            }
        }

        await MainActor.run {
            self.tracks = newTracks
            self.saveLibrary()
        }
    }

    public func saveLibrary() {
        let dict: [String: Any] = [
            "version": 1,
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "tracks": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(tracks))) ?? []
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
            try? data.write(to: libraryFile, options: .atomic)
        }
    }

    public func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            try? data.write(to: playlistsFile, options: .atomic)
        }
    }

    @discardableResult
    public func createPlaylist(name: String, trackIds: [String] = []) -> Playlist {
        let pl = Playlist(name: name, trackIds: trackIds)
        playlists.append(pl)
        savePlaylists()
        objectWillChange.send()
        return pl
    }

    public func renamePlaylist(id: String, newName: String) {
        if let index = playlists.firstIndex(where: { $0.id == id }) {
            playlists[index].name = newName
            playlists[index].updatedAt = Date()
            savePlaylists()
            objectWillChange.send()
        }
    }

    public func deletePlaylist(id: String) {
        playlists.removeAll(where: { $0.id == id })
        savePlaylists()
        objectWillChange.send()
    }

    public func addTrackToPlaylist(playlistId: String, trackId: String) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            if !playlists[index].trackIds.contains(trackId) {
                playlists[index].trackIds.append(trackId)
                playlists[index].updatedAt = Date()
                savePlaylists()
                objectWillChange.send()
            }
        }
    }

    public func removeTrackFromPlaylist(playlistId: String, trackId: String) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[index].trackIds.removeAll(where: { $0 == trackId })
            playlists[index].updatedAt = Date()
            savePlaylists()
            objectWillChange.send()
        }
    }

    public func deleteTrack(_ track: Track) {
        if let path = track.filePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tracks.removeAll(where: { $0.id == track.id })
        for i in 0..<playlists.count {
            playlists[i].trackIds.removeAll(where: { $0 == track.id })
        }
        saveLibrary()
        savePlaylists()
        objectWillChange.send()
    }

    public func getTrackById(_ id: String) -> Track? {
        if let exact = tracks.first(where: { $0.id == id }) {
            return exact
        }
        let targetName = (id as NSString).lastPathComponent
        guard !targetName.isEmpty else { return nil }
        return tracks.first(where: {
            ($0.id as NSString).lastPathComponent == targetName ||
            ($0.filePath != nil && ($0.filePath! as NSString).lastPathComponent == targetName)
        })
    }

    public func findTrack(id: String) -> Track? {
        return getTrackById(id)
    }

    public func getTracksForPlaylist(_ playlist: Playlist) -> [Track] {
        return playlist.trackIds.compactMap { getTrackById($0) }
    }

    public func exportBackupJson() -> String {
        let backup: [String: Any] = [
            "app": "DovvoPlay",
            "version": "2.0.0",
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "tracks": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(tracks))) ?? [],
            "playlists": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(playlists))) ?? []
        ]
        if let data = try? JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    public func importBackupJson(_ jsonString: String, replace: Bool = false) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if replace {
            playlists.removeAll()
        }

        if let plList = dict["playlists"] as? [[String: Any]],
           let plData = try? JSONSerialization.data(withJSONObject: plList),
           let decodedPlaylists = try? JSONDecoder().decode([Playlist].self, from: plData) {
            for p in decodedPlaylists {
                if let existingIdx = playlists.firstIndex(where: { $0.name.lowercased() == p.name.lowercased() }) {
                    for tId in p.trackIds {
                        if !playlists[existingIdx].trackIds.contains(tId) {
                            playlists[existingIdx].trackIds.append(tId)
                        }
                    }
                } else {
                    playlists.append(p)
                }
            }
        }

        savePlaylists()
        objectWillChange.send()
    }
}
