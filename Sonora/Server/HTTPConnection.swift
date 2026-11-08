import Foundation
import Network

/// Gestisce una singola connessione HTTP: legge la richiesta, scrive i file in streaming,
/// chiede al router la risposta e chiude.
final class HTTPConnection {

    typealias Router = (HTTPRequest, Data?, URL?, @escaping (HTTPResponse) -> Void) -> Void

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let router: Router
    private let onClose: (HTTPConnection) -> Void

    private static let maxHeaderBytes = 64 * 1024
    private static let maxMemoryBody = 8 * 1024 * 1024
    private static let separator = Data("\r\n\r\n".utf8)

    private var headBuffer = Data()
    private var request: HTTPRequest?
    private var readingBody = false
    private var bodyRemaining = 0
    private var memoryBody = Data()
    private var fileHandle: FileHandle?
    private var tempURL: URL?
    private var finished = false
    private var closed = false

    init(connection: NWConnection, queue: DispatchQueue, router: @escaping Router, onClose: @escaping (HTTPConnection) -> Void) {
        self.connection = connection
        self.queue = queue
        self.router = router
        self.onClose = onClose
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.cleanup()
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveNext()
    }

    private func receiveNext() {
        guard !finished else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty { self.ingest(data) }
            if error != nil { self.cleanup(); return }
            if isComplete {
                if !self.finished { self.handleEarlyEOF() }
                return
            }
            self.receiveNext()
        }
    }

    private func ingest(_ data: Data) {
        guard !finished else { return }
        if readingBody {
            consumeBody(data)
            return
        }
        headBuffer.append(data)
        guard let range = headBuffer.range(of: HTTPConnection.separator) else {
            if headBuffer.count > HTTPConnection.maxHeaderBytes {
                send(.text("Header troppo lungo", status: 400))
            }
            return
        }
        let headData = headBuffer.subdata(in: 0..<range.lowerBound)
        let leftover = headBuffer.subdata(in: range.upperBound..<headBuffer.count)
        headBuffer = Data()

        guard let headString = String(data: headData, encoding: .utf8) ?? String(data: headData, encoding: .isoLatin1),
              let req = HTTPRequest.parse(head: headString) else {
            send(.text("Richiesta non valida", status: 400))
            return
        }
        request = req

        if req.method == "OPTIONS" {
            send(HTTPResponse(status: 204, contentType: "text/plain", body: Data()))
            return
        }

        let length = req.contentLength
        if length <= 0 {
            route(body: nil, file: nil)
            return
        }

        if req.expectsContinue {
            let cont = Data("HTTP/1.1 100 Continue\r\n\r\n".utf8)
            connection.send(content: cont, completion: .contentProcessed { _ in })
        }

        readingBody = true
        bodyRemaining = length

        if HTTPConnection.isFileUpload(path: req.path) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("upload-\(UUID().uuidString).part")
            FileManager.default.createFile(atPath: tmp.path, contents: nil)
            tempURL = tmp
            fileHandle = try? FileHandle(forWritingTo: tmp)
            if fileHandle == nil {
                send(.text("Impossibile scrivere su disco", status: 500))
                return
            }
        } else if length > HTTPConnection.maxMemoryBody {
            send(.text("Corpo della richiesta troppo grande", status: 413))
            return
        }

        if !leftover.isEmpty { consumeBody(leftover) }
    }

    private static func isFileUpload(path: String) -> Bool {
        path.hasPrefix("/api/file/")
    }

    private func consumeBody(_ data: Data) {
        guard !finished, bodyRemaining > 0 else { return }
        let take = min(data.count, bodyRemaining)
        let chunk = take == data.count ? data : data.subdata(in: 0..<take)
        if let handle = fileHandle {
            do {
                try handle.write(contentsOf: chunk)
            } catch {
                send(.text("Errore di scrittura", status: 500))
                return
            }
        } else {
            memoryBody.append(chunk)
            if memoryBody.count > HTTPConnection.maxMemoryBody {
                send(.text("Corpo della richiesta troppo grande", status: 413))
                return
            }
        }
        bodyRemaining -= take
        if bodyRemaining <= 0 {
            try? fileHandle?.close()
            fileHandle = nil
            if let url = tempURL {
                route(body: nil, file: url)
            } else {
                route(body: memoryBody, file: nil)
            }
        }
    }

    private func handleEarlyEOF() {
        // la connessione si è chiusa prima di ricevere tutto il corpo
        try? fileHandle?.close()
        fileHandle = nil
        if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        tempURL = nil
        cleanup()
    }

    private func route(body: Data?, file: URL?) {
        guard let req = request, !finished else { return }
        router(req, body, file) { [weak self] response in
            self?.send(response)
        }
    }

    private func send(_ response: HTTPResponse) {
        guard !finished else { return }
        finished = true
        connection.send(content: response.serialized(), completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
            self?.cleanup()
        })
    }

    private func cleanup() {
        guard !closed else { return }
        closed = true
        try? fileHandle?.close()
        fileHandle = nil
        if let tempURL, FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempURL = nil
        memoryBody = Data()
        headBuffer = Data()
        onClose(self)
    }
}
