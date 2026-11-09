import Foundation
import SwiftUI

enum SortMode: String, CaseIterable, Identifiable {
    case title, artist, album, dateAdded
    var id: String { rawValue }
    var label: String {
        switch self {
        case .title: return "Titolo"
        case .artist: return "Artista"
        case .album: return "Album"
        case .dateAdded: return "Aggiunti di recente"
        }
    }
}

struct AudioFileInfo {
    let id: String
    let url: URL
    let size: Int64
    let modified: Date
}

@MainActor
final class LibraryStore: ObservableObject {

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanDone = 0
    @Published private(set) var scanTotal = 0
    @Published var sortMode: SortMode = .artist {
        didSet {
            UserDefaults.standard.set(sortMode.rawValue, forKey: "sortMode")
            tracks = sorted(tracks)
            publishSnapshot()
        }
    }
    @Published var lastMessage: String?

    private var didLoad = false

    // MARK: - ciclo di vita

    func bootstrap() async {
        guard !didLoad else { return }
        didLoad = true
        LibraryPaths.ensureDirectories()
        if let raw = UserDefaults.standard.string(forKey: "sortMode"), let m = SortMode(rawValue: raw) {
            sortMode = m
        }
        loadFromDisk()
        await rescan()
    }

    private func loadFromDisk() {
        let dec = JSONDecoder()
        if let data = try? Data(contentsOf: LibraryPaths.indexFile),
           let list = try? dec.decode([Track].self, from: data) {
            tracks = sorted(list)
        }
        if let data = try? Data(contentsOf: LibraryPaths.playlistsFile),
           let list = try? dec.decode([Playlist].self, from: data) {
            playlists = list
        }
        publishSnapshot()
    }

    private func saveIndex() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(tracks) {
            try? data.write(to: LibraryPaths.indexFile, options: .atomic)
        }
        publishSnapshot()
    }

    private func savePlaylists() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(playlists) {
            try? data.write(to: LibraryPaths.playlistsFile, options: .atomic)
        }
        publishSnapshot()
    }

    private func publishSnapshot() {
        LibrarySnapshot.shared.update(tracks: tracks, playlists: playlists)
    }

    // MARK: - scansione

    /// Rilegge la cartella Music/ e aggiorna l'indice.
    /// - Parameter force: se true rilegge i metadati anche dei file già noti.
    func rescan(force: Bool = false) async {
        guard !isScanning else { return }
        isScanning = true
        scanDone = 0
        scanTotal = 0
        defer { isScanning = false }

        LibraryPaths.ensureDirectories()
        let files = LibraryStore.collectAudioFiles()

        scanTotal = files.count
        let existing = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        var result: [Track] = []
        result.reserveCapacity(files.count)
        var processed = 0

        for file in files {
            processed += 1
            if processed % 5 == 0 { scanDone = processed }

            if !force, let old = existing[file.id], old.fileSize == file.size, old.duration > 0 {
                result.append(old)
                continue
            }

            let meta = await MetadataReader.read(url: file.url)
            var track = existing[file.id] ?? Track(id: file.id)
            track.title = meta.title ?? track.displayTitle
            track.artist = meta.artist ?? ""
            track.album = meta.album ?? ""
            track.albumArtist = meta.albumArtist ?? ""
            track.genre = meta.genre ?? ""
            track.year = meta.year ?? 0
            track.trackNumber = meta.trackNumber ?? 0
            track.discNumber = meta.discNumber ?? 0
            track.duration = meta.duration
            track.fileSize = file.size
            track.modified = file.modified
            if existing[file.id] == nil { track.dateAdded = Date() }

            let artKey = ArtworkStore.key(forAlbumArtist: track.effectiveAlbumArtist, album: track.displayAlbum)
            if let data = meta.artwork {
                if !ArtworkStore.exists(artKey) { ArtworkStore.store(data: data, id: artKey) }
                track.artworkID = artKey
            } else if let existing = track.artworkID, existing.hasPrefix("dl-"), ArtworkStore.exists(existing) {
                // copertina presa dal download online: la teniamo
            } else {
                track.artworkID = ArtworkStore.exists(artKey) ? artKey : nil
            }

            result.append(track)
        }

        scanDone = processed
        tracks = sorted(result)
        saveIndex()
    }

    /// Enumera i file audio dentro Music/. Sincrona di proposito: l'enumeratore
    /// di FileManager non si può iterare da un contesto asincrono.
    private static func collectAudioFiles() -> [AudioFileInfo] {
        let fm = FileManager.default
        let root = LibraryPaths.musicDirectory
        let rootPath = root.standardizedFileURL.path
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

        var files: [AudioFileInfo] = []
        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: keys,
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return files
        }
        for element in en {
            guard let url = element as? URL else { continue }
            let ext = url.pathExtension.lowercased()
            guard LibraryPaths.supportedExtensions.contains(ext) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            var rel = url.standardizedFileURL.path
            if rel.hasPrefix(rootPath) {
                rel = String(rel.dropFirst(rootPath.count))
                while rel.hasPrefix("/") { rel.removeFirst() }
            }
            files.append(AudioFileInfo(id: rel,
                                       url: url,
                                       size: Int64(values?.fileSize ?? 0),
                                       modified: values?.contentModificationDate ?? Date()))
        }
        return files
    }

    private func sorted(_ list: [Track]) -> [Track] {
        switch sortMode {
        case .title:
            return list.sorted { cmp($0.displayTitle, $1.displayTitle) }
        case .dateAdded:
            return list.sorted { $0.dateAdded > $1.dateAdded }
        case .album:
            return list.sorted { a, b in
                if a.displayAlbum.caseInsensitiveCompare(b.displayAlbum) != .orderedSame {
                    return cmp(a.displayAlbum, b.displayAlbum)
                }
                if a.discNumber != b.discNumber { return a.discNumber < b.discNumber }
                if a.trackNumber != b.trackNumber { return a.trackNumber < b.trackNumber }
                return cmp(a.displayTitle, b.displayTitle)
            }
        case .artist:
            return list.sorted { a, b in
                if a.effectiveAlbumArtist.caseInsensitiveCompare(b.effectiveAlbumArtist) != .orderedSame {
                    return cmp(a.effectiveAlbumArtist, b.effectiveAlbumArtist)
                }
                if a.displayAlbum.caseInsensitiveCompare(b.displayAlbum) != .orderedSame {
                    return cmp(a.displayAlbum, b.displayAlbum)
                }
                if a.discNumber != b.discNumber { return a.discNumber < b.discNumber }
                if a.trackNumber != b.trackNumber { return a.trackNumber < b.trackNumber }
                return cmp(a.displayTitle, b.displayTitle)
            }
        }
    }

    private func cmp(_ a: String, _ b: String) -> Bool {
        a.localizedStandardCompare(b) == .orderedAscending
    }

    // MARK: - raggruppamenti

    var albums: [AlbumGroup] {
        var map: [String: [Track]] = [:]
        for t in tracks { map[t.albumKey, default: []].append(t) }
        return map.map { key, value in
            let ordered = value.sorted {
                if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
                if $0.trackNumber != $1.trackNumber { return $0.trackNumber < $1.trackNumber }
                return cmp($0.displayTitle, $1.displayTitle)
            }
            return AlbumGroup(id: key,
                              title: ordered.first?.displayAlbum ?? "Album",
                              artist: ordered.first?.effectiveAlbumArtist ?? "",
                              tracks: ordered)
        }
        .sorted { cmp($0.title, $1.title) }
    }

    var artists: [ArtistGroup] {
        var map: [String: [Track]] = [:]
        for t in tracks { map[t.effectiveAlbumArtist.lowercased(), default: []].append(t) }
        return map.map { key, value in
            ArtistGroup(id: key,
                        name: value.first?.effectiveAlbumArtist ?? "Artista",
                        tracks: value.sorted { cmp($0.displayAlbum, $1.displayAlbum) },
                        albumCount: Set(value.map { $0.albumKey }).count)
        }
        .sorted { cmp($0.name, $1.name) }
    }

    func track(id: String) -> Track? { tracks.first { $0.id == id } }

    func tracks(in playlist: Playlist) -> [Track] {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return playlist.trackIDs.compactMap { byID[$0] }
    }

    func search(_ query: String) -> [Track] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.displayTitle.lowercased().contains(q)
            || $0.displayArtist.lowercased().contains(q)
            || $0.displayAlbum.lowercased().contains(q)
        }
    }

    // MARK: - import / delete

    func importFiles(_ urls: [URL]) async {
        var imported = 0
        var playlistsImported = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let ext = url.pathExtension.lowercased()
            if LibraryPaths.playlistExtensions.contains(ext) {
                if importM3U(at: url) { playlistsImported += 1 }
                continue
            }
            guard LibraryPaths.supportedExtensions.contains(ext) else { continue }
            let dest = LibraryPaths.uniqueDestination(for: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: dest)
                imported += 1
            } catch {
                lastMessage = "Errore copiando \(url.lastPathComponent)"
            }
        }
        if imported > 0 { await rescan() }
        var parts: [String] = []
        if imported > 0 { parts.append("\(imported) brani importati") }
        if playlistsImported > 0 { parts.append("\(playlistsImported) playlist importate") }
        if !parts.isEmpty { lastMessage = parts.joined(separator: ", ") }
    }

    /// Importa un file .m3u: le righe vengono confrontate con i nomi file già in libreria.
    @discardableResult
    func importM3U(at url: URL) -> Bool {
        guard let text = (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else { return false }
        let name = url.deletingPathExtension().lastPathComponent
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        let wanted = lines.map { ($0 as NSString).lastPathComponent.lowercased() }
        let byName = Dictionary(tracks.map { (($0.id as NSString).lastPathComponent.lowercased(), $0.id) },
                                uniquingKeysWith: { a, _ in a })
        let ids = wanted.compactMap { byName[$0] }
        guard !ids.isEmpty else { return false }
        createPlaylist(name: name, trackIDs: ids, source: "m3u")
        return true
    }

    func delete(tracks toDelete: [Track]) async {
        let fm = FileManager.default
        for t in toDelete { try? fm.removeItem(at: t.url) }
        let ids = Set(toDelete.map { $0.id })
        tracks.removeAll { ids.contains($0.id) }
        for i in playlists.indices { playlists[i].trackIDs.removeAll { ids.contains($0) } }
        saveIndex()
        savePlaylists()
    }

    // MARK: - playlist

    @discardableResult
    func createPlaylist(name: String, trackIDs: [String] = [], source: String = "locale") -> Playlist {
        var finalName = name.trimmingCharacters(in: .whitespaces)
        if finalName.isEmpty { finalName = "Nuova playlist" }
        if let idx = playlists.firstIndex(where: { $0.name.caseInsensitiveCompare(finalName) == .orderedSame }) {
            // playlist già esistente: la aggiorniamo invece di duplicarla
            var existing = playlists[idx]
            for id in trackIDs where !existing.trackIDs.contains(id) { existing.trackIDs.append(id) }
            playlists[idx] = existing
            savePlaylists()
            return existing
        }
        let p = Playlist(name: finalName, trackIDs: trackIDs, source: source)
        playlists.append(p)
        savePlaylists()
        return p
    }

    func rename(playlist: Playlist, to newName: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].name = newName.trimmingCharacters(in: .whitespaces)
        savePlaylists()
    }

    func deletePlaylists(ids: Set<UUID>) {
        for p in playlists where ids.contains(p.id) { CoverStore.remove(id: p.coverID) }
        playlists.removeAll { ids.contains($0.id) }
        savePlaylists()
    }

    func add(trackIDs: [String], to playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        for id in trackIDs where !playlists[idx].trackIDs.contains(id) {
            playlists[idx].trackIDs.append(id)
        }
        savePlaylists()
    }

    func removeTracks(at offsets: IndexSet, from playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].trackIDs.remove(atOffsets: offsets)
        savePlaylists()
    }

    func moveTracks(from source: IndexSet, to destination: Int, in playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].trackIDs.move(fromOffsets: source, toOffset: destination)
        savePlaylists()
    }

    // MARK: - copertine delle playlist

    func setCover(data: Data, for playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        guard let id = CoverStore.store(data: data, for: playlist.id) else {
            lastMessage = "Immagine non valida"
            return
        }
        playlists[idx].coverID = id
        savePlaylists()
        lastMessage = "Copertina aggiornata"
    }

    func removeCover(for playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        CoverStore.remove(id: playlists[idx].coverID)
        playlists[idx].coverID = nil
        savePlaylists()
    }

    /// Chiamata dal server quando il PC crea/aggiorna una playlist via API.
    func applyRemotePlaylist(name: String, fileNames: [String]) {
        let byName = Dictionary(tracks.map { (($0.id as NSString).lastPathComponent.lowercased(), $0.id) },
                                uniquingKeysWith: { a, _ in a })
        let ids = fileNames.compactMap { byName[($0 as NSString).lastPathComponent.lowercased()] }
        guard !ids.isEmpty else { return }
        createPlaylist(name: name, trackIDs: ids, source: "spotify")
    }

    var totalBytes: Int64 { tracks.reduce(0) { $0 + $1.fileSize } }
    var totalDuration: Double { tracks.reduce(0) { $0 + $1.duration } }


    /// Attacca una copertina presa da un download online a un file appena arrivato.
    func attachArtwork(_ data: Data, toFileNamed name: String) {
        guard let idx = tracks.firstIndex(where: { $0.id == name }) else { return }
        let key = "dl-" + ArtworkStore.key(forAlbumArtist: name, album: "online")
        guard ArtworkStore.store(data: data, id: key) else { return }
        tracks[idx].artworkID = key
        saveIndex()
    }

    // MARK: - backup

    var currentSettings: [String: String] {
        let d = UserDefaults.standard
        return [
            "sortMode": sortMode.rawValue,
            "shuffle": String(d.bool(forKey: "shuffle")),
            "repeatMode": d.string(forKey: "repeatMode") ?? "off",
            "serverAutoStart": String(d.bool(forKey: "serverAutoStart")),
            "autoBackup": String(d.object(forKey: "autoBackup") == nil ? true : d.bool(forKey: "autoBackup"))
        ]
    }

    func makeBackup() -> BackupFile {
        BackupManager.make(playlists: playlists, tracks: tracks, settings: currentSettings)
    }

    func backupData() -> Data? {
        try? BackupManager.encode(makeBackup())
    }

    /// Scrive il backup in un file temporaneo pronto da condividere.
    func exportBackup() -> URL? {
        do {
            return try BackupManager.writeTemporary(makeBackup())
        } catch {
            lastMessage = "Backup non riuscito"
            return nil
        }
    }

    /// Ripristina da un file di backup. `replace` sostituisce le playlist attuali
    /// invece di unirle.
    @discardableResult
    func importBackup(data: Data, replace: Bool) -> Bool {
        guard let backup = try? BackupManager.decode(data) else {
            lastMessage = "File di backup non valido"
            return false
        }
        let restoredCovers = BackupManager.restoreCovers(from: backup)

        if replace {
            playlists = backup.playlists
        } else {
            for incoming in backup.playlists {
                if let idx = playlists.firstIndex(where: { $0.name.caseInsensitiveCompare(incoming.name) == .orderedSame }) {
                    var merged = playlists[idx]
                    for id in incoming.trackIDs where !merged.trackIDs.contains(id) {
                        merged.trackIDs.append(id)
                    }
                    if merged.coverID == nil { merged.coverID = incoming.coverID }
                    playlists[idx] = merged
                } else {
                    playlists.append(incoming)
                }
            }
        }
        savePlaylists()
        applySettings(backup.settings)

        let known = Set(tracks.map { $0.id })
        let missing = backup.tracks.filter { !known.contains($0.id) }.count
        var parts = ["\(backup.playlists.count) playlist", "\(restoredCovers) copertine"]
        if missing > 0 { parts.append("\(missing) brani ancora da ricaricare") }
        lastMessage = "Ripristinato: " + parts.joined(separator: " · ")
        return true
    }

    private func applySettings(_ settings: [String: String]) {
        let d = UserDefaults.standard
        if let raw = settings["sortMode"], let mode = SortMode(rawValue: raw) { sortMode = mode }
        if let v = settings["serverAutoStart"] { d.set(v == "true", forKey: "serverAutoStart") }
        if let v = settings["shuffle"] { d.set(v == "true", forKey: "shuffle") }
        if let v = settings["repeatMode"] { d.set(v, forKey: "repeatMode") }
    }

    /// Copia di sicurezza automatica, al massimo una al giorno, ultime 5 tenute.
    func runAutoBackupIfNeeded() {
        let d = UserDefaults.standard
        if d.object(forKey: "autoBackup") == nil { d.set(true, forKey: "autoBackup") }
        guard d.bool(forKey: "autoBackup"), !playlists.isEmpty else { return }
        let last = (d.object(forKey: "lastAutoBackup") as? Date) ?? .distantPast
        guard Date().timeIntervalSince(last) > 24 * 3600 else { return }
        if BackupManager.autoBackup(makeBackup()) != nil {
            d.set(Date(), forKey: "lastAutoBackup")
        }
    }

    func restoreFromFile(at url: URL, replace: Bool) {
        guard let data = try? Data(contentsOf: url) else {
            lastMessage = "Copia non leggibile"
            return
        }
        importBackup(data: data, replace: replace)
    }

}
