import Foundation

/// Copia thread-safe della libreria, letta dal server HTTP (che vive su una coda di rete).
final class LibrarySnapshot {
    static let shared = LibrarySnapshot()
    private let lock = NSLock()
    private var _tracks: [Track] = []
    private var _playlists: [Playlist] = []

    var tracks: [Track] {
        lock.lock(); defer { lock.unlock() }
        return _tracks
    }

    var playlists: [Playlist] {
        lock.lock(); defer { lock.unlock() }
        return _playlists
    }

    func update(tracks: [Track], playlists: [Playlist]) {
        lock.lock()
        _tracks = tracks
        _playlists = playlists
        lock.unlock()
    }
}
