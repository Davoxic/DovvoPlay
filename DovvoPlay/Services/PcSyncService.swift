import Foundation
import Combine

public class PcSyncService: ObservableObject {
    public static let shared = PcSyncService()

    private let prefHostKey = "dovvoplay_pc_host_ip_v3"
    private let prefPortKey = "dovvoplay_pc_port_v3"
    public static let defaultPcPort: Int = 45678

    @Published public private(set) var pcHost: String = ""
    @Published public private(set) var pcPort: Int = PcSyncService.defaultPcPort
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var isPulling: Bool = false
    @Published public private(set) var statusMessage: String = "Nessun computer connesso"
    @Published public private(set) var activeTasks: [PcDownloadTask] = []
    @Published public private(set) var lastPulledCount: Int = 0
    @Published public private(set) var syncProgress: SyncProgress?
    @Published public private(set) var arrivedTracks: [String] = []

    public var isSyncing: Bool { syncProgress?.active == true }
    public var hasArrivedTracks: Bool { !arrivedTracks.isEmpty }
    public var baseUrl: String { "http://\(pcHost):\(pcPort)" }

    private var autoSyncTimer: Timer?
    private var progressTimer: Timer?

    private init() {
        loadSavedConfig()
    }

    private func loadSavedConfig() {
        self.pcHost = UserDefaults.standard.string(forKey: prefHostKey) ?? ""
        let savedPort = UserDefaults.standard.integer(forKey: prefPortKey)
        self.pcPort = savedPort > 0 ? savedPort : PcSyncService.defaultPcPort

        if !pcHost.isEmpty {
            Task {
                await testConnection()
            }
        }
    }

    public func setHostAndPort(host: String, port: Int) async {
        var clean = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("http://") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("https://") { clean = String(clean.dropFirst(8)) }
        if clean.contains("/") { clean = clean.components(separatedBy: "/")[0] }

        var resolvedPort = port
        if clean.contains(":") {
            let parts = clean.components(separatedBy: ":")
            clean = parts[0]
            if parts.count > 1, let p = Int(parts[1]), p > 0 {
                resolvedPort = p
            }
        }

        self.pcHost = clean
        self.pcPort = resolvedPort

        UserDefaults.standard.set(clean, forKey: prefHostKey)
        UserDefaults.standard.set(resolvedPort, forKey: prefPortKey)

        await testConnection()
    }

    public func disconnect() {
        stopAutoSync()
        stopProgressPolling()
        pcHost = ""
        isConnected = false
        syncProgress = nil
        activeTasks.removeAll()
        statusMessage = "Scollegato dal PC"
        UserDefaults.standard.removeObject(forKey: prefHostKey)
    }

    public func consumeArrivedTracks() -> [String] {
        let copy = arrivedTracks
        arrivedTracks.removeAll()
        return copy
    }

    @discardableResult
    public func testConnection() async -> Bool {
        guard !pcHost.isEmpty else {
            isConnected = false
            statusMessage = "Nessun indirizzo PC configurato"
            return false
        }

        statusMessage = "Verifica connessione con \(pcHost):\(pcPort)..."

        guard let pingURL = URL(string: "\(baseUrl)/ping") else {
            isConnected = false
            statusMessage = "URL server non valido"
            return false
        }

        var request = URLRequest(url: pingURL)
        request.timeoutInterval = 4.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                isConnected = true
                statusMessage = "Connesso al PC (\(pcHost):\(pcPort)) 🟢"
                startAutoSync()
                Task {
                    await syncPendingFromPc()
                }
                return true
            } else {
                isConnected = false
                statusMessage = "Il PC ha risposto con codice HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return false
            }
        } catch {
            isConnected = false
            statusMessage = "PC non raggiungibile: assicurati che il server PC sia avviato."
            return false
        }
    }

    // --- LAN DISCOVERY ---

    public func discoverPcOnLan(port: Int = PcSyncService.defaultPcPort) async -> String? {
        isSearching = true
        statusMessage = "Ricerca automatica PC su rete locale (porta \(port))..."

        let subnets = ["192.168.1", "192.168.0", "192.168.178", "10.0.0"]

        for subnet in subnets {
            // Check DHCP typical hosts (100..200)
            let dhcpHosts = Array(100...200)
            if let found = await probeSubnet(subnet: subnet, hosts: dhcpHosts, port: port) {
                await setHostAndPort(host: found, port: port)
                isSearching = false
                statusMessage = "PC trovato: \(found):\(port)! 🟢"
                return found
            }

            // Check low hosts (1..99)
            let lowHosts = Array(1...99)
            if let found = await probeSubnet(subnet: subnet, hosts: lowHosts, port: port) {
                await setHostAndPort(host: found, port: port)
                isSearching = false
                statusMessage = "PC trovato: \(found):\(port)! 🟢"
                return found
            }
        }

        isSearching = false
        if !isConnected {
            statusMessage = "Nessun server PC attivo trovato. Inserisci IP manualmente."
        }
        return nil
    }

    private func probeSubnet(subnet: String, hosts: [Int], port: Int) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            for h in hosts {
                group.addTask {
                    let target = "\(subnet).\(h)"
                    guard let url = URL(string: "http://\(target):\(port)/ping") else { return nil }
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 1.0
                    if let (_, res) = try? await URLSession.shared.data(for: req),
                       (res as? HTTPURLResponse)?.statusCode == 200 {
                        return target
                    }
                    return nil
                }
            }

            for await result in group {
                if let found = result {
                    group.cancelAll()
                    return found
                }
            }
            return nil
        }
    }

    // --- PULL FROM PC ---

    @discardableResult
    public func syncPendingFromPc(onStatus: ((String) -> Void)? = nil) async -> Int {
        guard !pcHost.isEmpty && !isPulling else { return 0 }
        isPulling = true
        var savedCount = 0

        defer {
            isPulling = false
        }

        guard let pendingURL = URL(string: "\(baseUrl)/api/pending") else { return 0 }
        var req = URLRequest(url: pendingURL)
        req.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["files"] as? [[String: Any]], !files.isEmpty else {
                return 0
            }

            let musicDir = LibraryService.shared.musicDirectory
            var playlistGroups: [String: [String]] = [:]

            for f in files {
                guard let fileName = f["fileName"] as? String, !fileName.isEmpty else { continue }
                let label = (f["title"] as? String) ?? fileName

                onStatus?("Ricevo dal PC: \(label)")
                statusMessage = "Ricevo dal PC: \(label)"

                guard let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                      let fileURL = URL(string: "\(baseUrl)/api/file/\(encoded)") else { continue }

                var fileReq = URLRequest(url: fileURL)
                fileReq.timeoutInterval = 300.0 // 5 minutes

                if let (fileData, fileRes) = try? await URLSession.shared.data(for: fileReq),
                   (fileRes as? HTTPURLResponse)?.statusCode == 200, !fileData.isEmpty {

                    let dest = musicDir.appendingPathComponent(fileName)
                    try? fileData.write(to: dest, options: .atomic)
                    savedCount += 1

                    arrivedTracks.append(label)

                    if let plName = f["playlist"] as? String, !plName.isEmpty, plName != "null" {
                        playlistGroups[plName, default: []].append(fileName)
                    }

                    // Acknowledge to PC
                    if let ackURL = URL(string: "\(baseUrl)/api/pending/\(encoded)/ack") {
                        var ackReq = URLRequest(url: ackURL)
                        ackReq.httpMethod = "POST"
                        _ = try? await URLSession.shared.data(for: ackReq)
                    }
                }
            }

            if savedCount > 0 {
                await LibraryService.shared.scanLibrary()

                for (plName, filenames) in playlistGroups {
                    let tracks = LibraryService.shared.tracks
                    var trackIds: [String] = []
                    for fn in filenames {
                        if let matched = tracks.first(where: { ($0.filePath != nil && $0.filePath!.hasSuffix(fn)) || $0.id.hasSuffix(fn) }) {
                            trackIds.append(matched.id)
                        }
                    }
                    if !trackIds.isEmpty {
                        LibraryService.shared.createPlaylist(name: plName, trackIds: trackIds)
                    }
                }

                lastPulledCount = savedCount
                statusMessage = savedCount == 1 ? "1 brano ricevuto dal PC 🎵" : "\(savedCount) brani ricevuti dal PC 🎵"
            }
        } catch {
            print("Errore syncPendingFromPc: \(error)")
        }

        return savedCount
    }

    // --- PLAYLIST SYNC ---

    public func startPlaylistSync(playlistUrl: String, createPlaylist: Bool = false, onStatus: ((String) -> Void)? = nil) async -> Bool {
        guard !pcHost.isEmpty else {
            onStatus?("Nessun PC configurato.")
            return false
        }

        let cleanUrl = playlistUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty,
              let syncURL = URL(string: "\(baseUrl)/api/playlist_sync") else { return false }

        let deviceSongs = LibraryService.shared.tracks.map { t in
            [
                "id": t.id,
                "title": t.title,
                "artist": t.artist,
                "album": t.album,
                "duration": Double(t.durationMs) / 1000.0
            ]
        }

        onStatus?("Invio al PC la playlist e \(deviceSongs.count) brani in libreria...")

        let bodyDict: [String: Any] = [
            "playlist_url": cleanUrl,
            "device_songs": deviceSongs,
            "auto_download_missing": true,
            "create_playlist": createPlaylist
        ]

        var req = URLRequest(url: syncURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20.0
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                onStatus?("Il PC non ha risposto correttamente.")
                return false
            }

            if let progressRaw = json["progress"] as? [String: Any],
               let pData = try? JSONSerialization.data(withJSONObject: progressRaw),
               let p = try? JSONDecoder().decode(SyncProgress.self, from: pData) {
                self.syncProgress = p
            }

            startProgressPolling()
            onStatus?("Sincronizzazione avviata sul PC.")
            return true
        } catch {
            onStatus?("Errore comunicazione PC: \(error.localizedDescription)")
            return false
        }
    }

    public func fetchSyncProgress() async -> SyncProgress? {
        guard !pcHost.isEmpty, let progressURL = URL(string: "\(baseUrl)/api/sync/progress") else { return nil }

        var req = URLRequest(url: progressURL)
        req.timeoutInterval = 8.0

        if let (data, response) = try? await URLSession.shared.data(for: req),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let progressRaw = json["progress"] as? [String: Any],
           let pData = try? JSONSerialization.data(withJSONObject: progressRaw),
           let p = try? JSONDecoder().decode(SyncProgress.self, from: pData) {
            DispatchQueue.main.async {
                self.syncProgress = p
            }
            return p
        }
        return syncProgress
    }

    private func startProgressPolling() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                let p = await self.fetchSyncProgress()
                await self.syncPendingFromPc()
                if p == nil || p?.active == false {
                    self.stopProgressPolling()
                    await self.syncPendingFromPc()
                }
            }
        }
    }

    public func stopProgressPolling() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    public func startAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.pcHost.isEmpty else { return }
            Task {
                await self.syncPendingFromPc()
            }
        }
    }

    public func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    public func fetchTasks() async {
        guard !pcHost.isEmpty, let url = URL(string: "\(baseUrl)/api/tasks") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 6.0

        if let (data, response) = try? await URLSession.shared.data(for: req),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tasksList = json["tasks"] as? [[String: Any]],
           let tData = try? JSONSerialization.data(withJSONObject: tasksList),
           let decoded = try? JSONDecoder().decode([PcDownloadTask].self, from: tData) {
            DispatchQueue.main.async {
                self.activeTasks = decoded
            }
        }
    }

    public func sendDownloadRequest(service: String, queryOrUrl: String, title: String, artist: String) async -> Bool {
        guard let url = URL(string: "\(baseUrl)/api/download") else { return false }
        let payload: [String: Any] = [
            "service": service,
            "query": queryOrUrl,
            "title": title,
            "artist": artist
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        if let (_, response) = try? await URLSession.shared.data(for: req),
           let code = (response as? HTTPURLResponse)?.statusCode, (code == 200 || code == 202) {
            activeTasks.insert(PcDownloadTask(
                id: "\(Int(Date().timeIntervalSince1970 * 1000))",
                title: title,
                artist: artist,
                service: service,
                status: "downloading sul PC..."
            ), at: 0)
            return true
        }
        return false
    }
}
