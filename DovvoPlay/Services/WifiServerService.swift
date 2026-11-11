import Foundation
import Network
import Combine

public class WifiServerService: ObservableObject {
    public static let shared = WifiServerService()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var ipAddress: String = "127.0.0.1"
    @Published public private(set) var port: Int = 8080
    @Published public private(set) var recentUploads: [String] = []

    public var serverUrl: String {
        return "http://\(ipAddress):\(port)"
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.dchietti.dovvoplay.wifiserver", qos: .userInitiated)

    private init() {
        updateIpAddress()
    }

    public func toggle() async {
        if isRunning {
            await stop()
        } else {
            await start()
        }
    }

    public func updateIpAddress() {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    // en0 is Wi-Fi on iOS
                    if name == "en0" || name.starts(with: "en") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        let ip = String(cString: hostname)
                        if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254") {
                            address = ip
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        DispatchQueue.main.async {
            self.ipAddress = address
        }
    }

    public func start() async {
        guard !isRunning else { return }
        updateIpAddress()

        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true

            let newListener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: UInt16(self.port))!)
            self.listener = newListener

            newListener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self.isRunning = true
                    case .failed(let err):
                        print("WifiServer listener fallito: \(err)")
                        self.isRunning = false
                    case .cancelled:
                        self.isRunning = false
                    default:
                        break
                    }
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            newListener.start(queue: queue)
        } catch {
            print("Impossibile avviare il server Wi-Fi: \(error)")
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    public func stop() async {
        guard isRunning else { return }
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    // --- CONNECTION HANDLING ---

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveData(connection: connection, buffer: Data())
    }

    private func receiveData(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            var currentBuffer = buffer
            if let content = content {
                currentBuffer.append(content)
            }

            // Check if HTTP header is complete (\r\n\r\n)
            if let range = currentBuffer.range(of: Data([13, 10, 13, 10])) {
                let headerData = currentBuffer.subdata(in: 0..<range.lowerBound)
                guard let headerStr = String(data: headerData, encoding: .utf8) else {
                    self.sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
                    return
                }

                let lines = headerStr.components(separatedBy: "\r\n")
                guard let requestLine = lines.first else {
                    self.sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
                    return
                }

                let parts = requestLine.components(separatedBy: " ")
                guard parts.count >= 2 else {
                    self.sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
                    return
                }

                let method = parts[0].uppercased()
                let fullPath = parts[1]

                // Content-Length check
                var contentLength = 0
                for line in lines {
                    let lower = line.lowercased()
                    if lower.hasPrefix("content-length:") {
                        let valStr = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                        contentLength = Int(valStr) ?? 0
                    }
                }

                let bodyStart = range.upperBound
                let totalNeeded = bodyStart + contentLength

                if currentBuffer.count < totalNeeded && !isComplete {
                    // Need more body data
                    self.receiveData(connection: connection, buffer: currentBuffer)
                    return
                }

                let bodyData = currentBuffer.count > bodyStart ? currentBuffer.subdata(in: bodyStart..<min(currentBuffer.count, totalNeeded)) : Data()
                self.processRequest(connection: connection, method: method, path: fullPath, headers: lines, body: bodyData)
            } else if isComplete {
                connection.cancel()
            } else if error == nil {
                self.receiveData(connection: connection, buffer: currentBuffer)
            }
        }
    }

    private func processRequest(connection: NWConnection, method: String, path: String, headers: [String], body: Data) {
        // CORS preflight
        if method == "OPTIONS" {
            sendResponse(connection: connection, statusCode: 200, contentType: "text/plain", body: "")
            return
        }

        let cleanPath = path.components(separatedBy: "?")[0]

        // Routing
        if cleanPath == "/" || cleanPath == "/index.html" {
            sendResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: WifiServerService.webPageHtml)
        } else if cleanPath == "/api/ping" {
            let json = "{\"ok\":true,\"app\":\"DovvoPlay\",\"version\":\"2.0.0\"}"
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: json)
        } else if cleanPath == "/api/library" {
            let tracks = LibraryService.shared.tracks
            if let data = try? JSONEncoder().encode(tracks), let jsonStr = String(data: data, encoding: .utf8) {
                let res = "{\"ok\":true,\"tracks\":\(jsonStr),\"count\":\(tracks.count)}"
                sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: res)
            } else {
                sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: "{\"ok\":true,\"tracks\":[],\"count\":0}")
            }
        } else if cleanPath.hasPrefix("/api/file/") {
            let encodedName = cleanPath.replacingOccurrences(of: "/api/file/", with: "")
            let fileName = encodedName.removingPercentEncoding ?? encodedName
            handleFileEndpoint(connection: connection, method: method, fileName: fileName, body: body)
        } else if cleanPath == "/api/playlist" && method == "POST" {
            handlePlaylistEndpoint(connection: connection, body: body)
        } else if cleanPath == "/upload" && method == "POST" {
            handleUploadEndpoint(connection: connection, headers: headers, body: body)
        } else {
            sendResponse(connection: connection, statusCode: 404, contentType: "text/plain", body: "404 Not Found")
        }
    }

    private func handleFileEndpoint(connection: NWConnection, method: String, fileName: String, body: Data) {
        let musicDir = LibraryService.shared.musicDirectory
        let targetFile = musicDir.appendingPathComponent(fileName)

        if method == "PUT" {
            do {
                try body.write(to: targetFile, options: .atomic)
                recordUpload(fileName)
                Task {
                    await LibraryService.shared.scanLibrary()
                }
                sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: "{\"ok\":true,\"file\":\"\(fileName)\"}")
            } catch {
                sendResponse(connection: connection, statusCode: 500, contentType: "application/json", body: "{\"ok\":false,\"error\":\"\(error.localizedDescription)\"}")
            }
        } else if method == "DELETE" {
            try? FileManager.default.removeItem(at: targetFile)
            Task {
                await LibraryService.shared.scanLibrary()
            }
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: "{\"ok\":true,\"deleted\":\"\(fileName)\"}")
        } else {
            sendResponse(connection: connection, statusCode: 405, body: "Method Not Allowed")
        }
    }

    private func handlePlaylistEndpoint(connection: NWConnection, body: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let name = json["name"] as? String,
              let files = json["files"] as? [String] else {
            sendResponse(connection: connection, statusCode: 400, contentType: "application/json", body: "{\"ok\":false,\"error\":\"Payload non valido\"}")
            return
        }

        var trackIds: [String] = []
        let allTracks = LibraryService.shared.tracks

        for f in files {
            for t in allTracks {
                if t.id.hasSuffix(f) || (t.filePath != nil && t.filePath!.hasSuffix(f)) {
                    trackIds.append(t.id)
                    break
                }
            }
        }

        if trackIds.isEmpty {
            sendResponse(connection: connection, statusCode: 400, contentType: "application/json", body: "{\"ok\":false,\"error\":\"Nessun file trovato in libreria\"}")
            return
        }

        let pl = LibraryService.shared.createPlaylist(name: name, trackIds: trackIds)
        if let plData = try? JSONEncoder().encode(pl), let plStr = String(data: plData, encoding: .utf8) {
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: "{\"ok\":true,\"playlist\":\(plStr)}")
        } else {
            sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: "{\"ok\":true}")
        }
    }

    private func handleUploadEndpoint(connection: NWConnection, headers: [String], body: Data) {
        var boundary: String?
        for h in headers {
            let lower = h.lowercased()
            if lower.contains("content-type:") && lower.contains("boundary=") {
                if let r = h.range(of: "boundary=") {
                    boundary = String(h[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                }
            }
        }

        guard let boundary = boundary, !boundary.isEmpty else {
            sendResponse(connection: connection, statusCode: 400, body: "Expected multipart boundary")
            return
        }

        let boundaryData = ("--" + boundary).data(using: .utf8)!
        let parts = splitData(body, by: boundaryData)
        let musicDir = LibraryService.shared.musicDirectory
        var uploadedCount = 0

        for part in parts {
            guard part.count > 4 else { continue }
            if let headerEndRange = part.range(of: Data([13, 10, 13, 10])) {
                let partHeaderData = part.subdata(in: 0..<headerEndRange.lowerBound)
                if let partHeaderStr = String(data: partHeaderData, encoding: .utf8) {
                    if let filenameMatch = partHeaderStr.range(of: "filename=\"") {
                        let rest = partHeaderStr[filenameMatch.upperBound...]
                        if let quoteEnd = rest.range(of: "\"") {
                            var filename = String(rest[..<quoteEnd.lowerBound])
                            filename = filename.replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "_", options: .regularExpression)
                            if !filename.isEmpty {
                                var fileData = part.subdata(in: headerEndRange.upperBound..<part.count)
                                // Trim trailing \r\n
                                if fileData.count >= 2 && fileData[fileData.count - 2] == 13 && fileData[fileData.count - 1] == 10 {
                                    fileData = fileData.subdata(in: 0..<fileData.count - 2)
                                }
                                let targetURL = musicDir.appendingPathComponent(filename)
                                if (try? fileData.write(to: targetURL, options: .atomic)) != nil {
                                    recordUpload(filename)
                                    uploadedCount += 1
                                }
                            }
                        }
                    }
                }
            }
        }

        Task {
            await LibraryService.shared.scanLibrary()
        }

        sendResponse(connection: connection, statusCode: 200, contentType: "application/json", body: "{\"ok\":true,\"count\":\(uploadedCount)}")
    }

    private func splitData(_ data: Data, by delimiter: Data) -> [Data] {
        var result: [Data] = []
        var searchRange: Range<Data.Index> = 0..<data.count

        while let match = data.range(of: delimiter, options: [], in: searchRange) {
            let part = data.subdata(in: searchRange.lowerBound..<match.lowerBound)
            if !part.isEmpty {
                result.append(part)
            }
            searchRange = match.upperBound..<data.count
        }

        if searchRange.lowerBound < data.count {
            let tail = data.subdata(in: searchRange.lowerBound..<data.count)
            if !tail.isEmpty {
                result.append(tail)
            }
        }
        return result
    }

    private func recordUpload(_ filename: String) {
        DispatchQueue.main.async {
            self.recentUploads.insert(filename, at: 0)
            if self.recentUploads.count > 30 {
                self.recentUploads.removeLast()
            }
        }
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, contentType: String = "text/plain", body: String) {
        let bodyData = body.data(using: .utf8) ?? Data()
        var responseStr = "HTTP/1.1 \(statusCode) OK\r\n"
        responseStr += "Content-Type: \(contentType)\r\n"
        responseStr += "Content-Length: \(bodyData.count)\r\n"
        responseStr += "Access-Control-Allow-Origin: *\r\n"
        responseStr += "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n"
        responseStr += "Access-Control-Allow-Headers: Content-Type, Content-Length\r\n"
        responseStr += "Connection: close\r\n\r\n"

        var fullData = responseStr.data(using: .utf8)!
        fullData.append(bodyData)

        connection.send(content: fullData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    public static let webPageHtml = """
    <!DOCTYPE html>
    <html lang="it">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DovvoPlay · Carica Musica</title>
    <style>
      :root {
        --bg: #0d0a17; --bg2: #171029; --card: rgba(255,255,255,.06);
        --line: rgba(255,255,255,.12); --text: #f2eefb; --muted: #a79dc0;
        --accent: #ffd700; --accent2: #d4af37; --ok: #4ade80;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0; min-height: 100vh; color: var(--text);
        font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        background: radial-gradient(1200px 600px at 20% -10%, #3a2e1d 0%, transparent 60%), linear-gradient(160deg, var(--bg), var(--bg2));
        padding: 32px 16px 60px;
      }
      .wrap { max-width: 680px; margin: 0 auto; }
      header { display: flex; align-items: center; gap: 14px; margin-bottom: 24px; }
      .logo {
        width: 48px; height: 48px; border-radius: 14px;
        background: conic-gradient(from 210deg, var(--accent), var(--accent2), var(--accent));
        display: grid; place-items: center; font-weight: bold; font-size: 22px; color: #000;
      }
      h1 { font-size: 24px; margin: 0; font-weight: 700; }
      .sub { color: var(--muted); font-size: 13px; }
      .drop {
        border: 2px dashed var(--line); border-radius: 20px; padding: 48px 20px; text-align: center;
        background: var(--card); transition: .2s; cursor: pointer;
      }
      .drop:hover, .drop.over { border-color: var(--accent); background: rgba(255,215,0,.12); }
      .btn {
        display: inline-block; margin-top: 18px; padding: 12px 28px; border-radius: 999px; border: 0;
        background: linear-gradient(120deg, var(--accent), var(--accent2)); color: #000; font-weight: 700;
        font-size: 15px; cursor: pointer;
      }
      input[type=file] { display: none; }
      ul { list-style: none; padding: 0; margin: 24px 0 0; }
      li {
        padding: 12px 16px; border: 1px solid var(--line); border-radius: 12px; margin-bottom: 8px;
        background: var(--card); display: flex; justify-content: space-between; font-size: 14px;
      }
      .ok { color: var(--ok); font-weight: 600; }
    </style>
    </head>
    <body>
    <div class="wrap">
      <header>
        <div class="logo">⚡</div>
        <div>
          <h1>DovvoPlay iOS Native</h1>
          <div class="sub">Carica musica direttamente sul tuo iPhone via Wi-Fi</div>
        </div>
      </header>
      <div class="drop" id="drop">
        <h2 style="margin:0 0 8px;">Trascina qui i tuoi brani</h2>
        <p style="margin:0; color:var(--muted);">MP3, M4A, WAV, FLAC, AAC — anche selezioni multiple</p>
        <button class="btn" id="pick" type="button">Scegli file dal computer</button>
        <input type="file" id="file" multiple accept="audio/*,.mp3,.m4a,.wav,.flac,.aac">
      </div>
      <ul id="list"></ul>
    </div>
    <script>
      const drop = document.getElementById('drop');
      const fileInput = document.getElementById('file');
      const pick = document.getElementById('pick');
      const list = document.getElementById('list');
      pick.onclick = () => fileInput.click();
      fileInput.onchange = () => handleFiles(fileInput.files);
      drop.ondragover = (e) => { e.preventDefault(); drop.classList.add('over'); };
      drop.ondragleave = () => drop.classList.remove('over');
      drop.ondrop = (e) => {
        e.preventDefault();
        drop.classList.remove('over');
        handleFiles(e.dataTransfer.files);
      };
      async function handleFiles(files) {
        for (const f of files) {
          const li = document.createElement('li');
          li.innerHTML = '<span>' + f.name + '</span><span style="color:var(--muted)">caricamento...</span>';
          list.prepend(li);
          const formData = new FormData();
          formData.append('file', f);
          try {
            const res = await fetch('/upload', { method: 'POST', body: formData });
            if (res.ok) {
              li.querySelector('span:last-child').className = 'ok';
              li.querySelector('span:last-child').textContent = '✓ Caricato';
            } else {
              li.querySelector('span:last-child').textContent = 'Errore';
            }
          } catch (e) {
            li.querySelector('span:last-child').textContent = 'Errore connessione';
          }
        }
      }
    </script>
    </body>
    </html>
    """
}
