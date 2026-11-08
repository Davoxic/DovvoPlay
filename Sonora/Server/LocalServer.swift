import Foundation
import Network
import UIKit

/// Server HTTP sulla rete locale: serve la pagina di upload e le API usate dal tool su PC.
final class LocalServer: ObservableObject {

    static let shared = LocalServer()

    @Published private(set) var isRunning = false
    @Published private(set) var port: UInt16 = 8080
    @Published private(set) var addresses: [String] = []
    @Published private(set) var uploadedCount = 0
    @Published private(set) var lastEvent: String?
    @Published private(set) var lastError: String?

    /// Chiamata (sul main) quando sono arrivati nuovi file.
    var onLibraryChanged: (() -> Void)?
    /// Chiamata (sul main) quando il PC invia una playlist.
    var onPlaylistReceived: ((String, [String]) -> Void)?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "sonora.server", qos: .userInitiated)
    private var connections: [ObjectIdentifier: HTTPConnection] = [:]
    private var rescanWork: DispatchWorkItem?

    private static let candidatePorts: [UInt16] = [8080, 8081, 8088, 8090, 9000, 9090]

    var primaryURL: String? {
        guard isRunning, let ip = addresses.first else { return nil }
        return "http://\(ip):\(port)"
    }

    // MARK: - avvio / arresto

    func start() {
        stop()
        let ips = NetworkInfo.localAddresses()
        DispatchQueue.main.async { self.addresses = ips }

        var started = false
        for candidate in LocalServer.candidatePorts {
            guard let nwPort = NWEndpoint.Port(rawValue: candidate) else { continue }
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.includePeerToPeer = false
            do {
                let l = try NWListener(using: params, on: nwPort)
                l.service = NWListener.Service(name: "Sonora", type: "_sonora._tcp")
                l.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        DispatchQueue.main.async {
                            self.isRunning = true
                            self.lastError = nil
                            self.addresses = NetworkInfo.localAddresses()
                        }
                    case .failed(let error):
                        DispatchQueue.main.async {
                            self.isRunning = false
                            self.lastError = error.localizedDescription
                        }
                        self.stop()
                    case .cancelled:
                        DispatchQueue.main.async { self.isRunning = false }
                    default:
                        break
                    }
                }
                l.newConnectionHandler = { [weak self] conn in
                    self?.accept(conn)
                }
                l.start(queue: queue)
                listener = l
                DispatchQueue.main.async { self.port = candidate }
                started = true
                break
            } catch {
                continue
            }
        }
        if !started {
            DispatchQueue.main.async {
                self.lastError = "Nessuna porta disponibile"
                self.isRunning = false
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        queue.async {
            self.connections.removeAll()
        }
        DispatchQueue.main.async { self.isRunning = false }
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func refreshAddresses() {
        let ips = NetworkInfo.localAddresses()
        DispatchQueue.main.async { self.addresses = ips }
    }

    private func accept(_ nwConnection: NWConnection) {
        let conn = HTTPConnection(connection: nwConnection,
                                  queue: queue,
                                  router: { [weak self] req, body, file, respond in
                                      self?.handle(request: req, body: body, file: file, respond: respond)
                                  },
                                  onClose: { [weak self] c in
                                      self?.queue.async { self?.connections.removeValue(forKey: ObjectIdentifier(c)) }
                                  })
        connections[ObjectIdentifier(conn)] = conn
        conn.start()
    }

    // MARK: - routing

    private func handle(request: HTTPRequest, body: Data?, file: URL?, respond: @escaping (HTTPResponse) -> Void) {
        let path = request.path

        switch (request.method, path) {

        case ("GET", "/"), ("GET", "/index.html"):
            respond(.html(UploadPage.html))

        case ("GET", "/favicon.ico"):
            respond(HTTPResponse(status: 204, contentType: "image/x-icon", body: Data()))

        case ("GET", "/api/ping"):
            respond(.json([
                "app": "sonora",
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                "device": UIDevice.current.name,
                "tracks": LibrarySnapshot.shared.tracks.count
            ]))

        case ("GET", "/api/library"):
            let tracks = LibrarySnapshot.shared.tracks.map { t -> [String: Any] in
                [
                    "file": t.fileName,
                    "title": t.displayTitle,
                    "artist": t.displayArtist,
                    "album": t.displayAlbum,
                    "duration": Int(t.duration.rounded()),
                    "size": t.fileSize
                ]
            }
            let playlists = LibrarySnapshot.shared.playlists.map { p -> [String: Any] in
                ["name": p.name, "tracks": p.trackIDs]
            }
            respond(.json(["count": tracks.count, "tracks": tracks, "playlists": playlists]))

        case ("POST", "/api/playlist"):
            guard let body,
                  let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let name = obj["name"] as? String else {
                respond(.json(["error": "JSON non valido, serve {\"name\":…, \"files\":[…]}"], status: 400))
                return
            }
            let files = (obj["files"] as? [String]) ?? []
            DispatchQueue.main.async { self.onPlaylistReceived?(name, files) }
            respond(.json(["ok": true, "name": name, "files": files.count]))

        default:
            if request.method == "PUT", path.hasPrefix("/api/file/") {
                handleUpload(request: request, tempFile: file, respond: respond)
                return
            }
            if request.method == "DELETE", path.hasPrefix("/api/file/") {
                handleDelete(request: request, respond: respond)
                return
            }
            respond(.json(["error": "Endpoint non trovato", "path": path], status: 404))
        }
    }

    private func handleUpload(request: HTTPRequest, tempFile: URL?, respond: @escaping (HTTPResponse) -> Void) {
        guard let tempFile else {
            respond(.json(["error": "Corpo mancante"], status: 400))
            return
        }
        let raw = String(request.path.dropFirst("/api/file/".count))
        let name = LibraryPaths.sanitize(fileName: raw)
        let ext = (name as NSString).pathExtension.lowercased()
        guard LibraryPaths.supportedExtensions.contains(ext) || LibraryPaths.playlistExtensions.contains(ext) else {
            try? FileManager.default.removeItem(at: tempFile)
            respond(.json(["error": "Estensione non supportata: .\(ext)"], status: 415))
            return
        }

        LibraryPaths.ensureDirectories()
        let overwrite = (request.query["overwrite"] ?? "") == "1"
        let direct = LibraryPaths.musicDirectory.appendingPathComponent(name)
        let destination: URL
        if overwrite {
            try? FileManager.default.removeItem(at: direct)
            destination = direct
        } else {
            destination = LibraryPaths.uniqueDestination(for: name)
        }

        do {
            try FileManager.default.moveItem(at: tempFile, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: tempFile)
            respond(.json(["error": "Salvataggio fallito: \(error.localizedDescription)"], status: 500))
            return
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        DispatchQueue.main.async {
            self.uploadedCount += 1
            self.lastEvent = "Ricevuto \(destination.lastPathComponent)"
        }
        scheduleRescan()
        respond(.json(["ok": true, "file": destination.lastPathComponent, "size": size], status: 201))
    }

    private func handleDelete(request: HTTPRequest, respond: @escaping (HTTPResponse) -> Void) {
        let raw = String(request.path.dropFirst("/api/file/".count))
        let name = LibraryPaths.sanitize(fileName: raw)
        let url = LibraryPaths.musicDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            respond(.json(["error": "File non trovato", "file": name], status: 404))
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
            scheduleRescan()
            respond(.json(["ok": true, "deleted": name]))
        } catch {
            respond(.json(["error": error.localizedDescription], status: 500))
        }
    }

    /// Dopo una raffica di upload facciamo una sola riscansione.
    private func scheduleRescan() {
        rescanWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.onLibraryChanged?() }
        }
        rescanWork = work
        queue.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
