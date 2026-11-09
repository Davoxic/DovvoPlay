import Foundation

/// Scarica file tenendo traccia dell'avanzamento.
@MainActor
final class DownloadManager: NSObject, ObservableObject {

    static let shared = DownloadManager()

    struct Job: Identifiable {
        let id: String
        var title: String
        var progress: Double
        var fileName: String
    }

    @Published private(set) var jobs: [String: Job] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 1800
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var waiters: [Int: CheckedContinuation<URL, Error>] = [:]
    private var targets: [Int: (id: String, destination: URL)] = [:]

    enum DownloadError: LocalizedError {
        case http(Int)
        case cannotWrite

        var errorDescription: String? {
            switch self {
            case .http(let code): return "Il server ha risposto \(code)"
            case .cannotWrite: return "Non riesco a scrivere il file sul telefono"
            }
        }
    }

    func progress(for id: String) -> Double? { jobs[id]?.progress }
    func isRunning(_ id: String) -> Bool { jobs[id] != nil }

    @discardableResult
    func download(_ url: URL, to destination: URL, id: String, title: String) async throws -> URL {
        jobs[id] = Job(id: id, title: title, progress: 0, fileName: destination.lastPathComponent)
        defer { jobs[id] = nil }

        let task = session.downloadTask(with: url)
        targets[task.taskIdentifier] = (id, destination)
        return try await withCheckedThrowingContinuation { continuation in
            waiters[task.taskIdentifier] = continuation
            task.resume()
        }
    }

    // MARK: - callback dal delegato

    fileprivate func setProgress(_ taskID: Int, _ value: Double) {
        guard let target = targets[taskID], var job = jobs[target.id] else { return }
        job.progress = min(max(value, 0), 1)
        jobs[target.id] = job
    }

    fileprivate func finish(_ taskID: Int, tempFile: URL?, error: Error?) {
        guard let continuation = waiters.removeValue(forKey: taskID) else {
            if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
            targets[taskID] = nil
            return
        }
        let target = targets.removeValue(forKey: taskID)

        if let error {
            if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
            continuation.resume(throwing: error)
            return
        }
        guard let tempFile, let destination = target?.destination else {
            continuation.resume(throwing: DownloadError.cannotWrite)
            return
        }
        do {
            let parent = destination.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parent.path) {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempFile, to: destination)
            continuation.resume(returning: destination)
        } catch {
            try? FileManager.default.removeItem(at: tempFile)
            continuation.resume(throwing: error)
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200

        // il file temporaneo sparisce appena questo metodo ritorna: va spostato subito
        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-\(UUID().uuidString)")
        let moved = (try? FileManager.default.moveItem(at: location, to: staged)) != nil

        Task { @MainActor in
            if status >= 400 {
                if moved { try? FileManager.default.removeItem(at: staged) }
                self.finish(taskID, tempFile: nil, error: DownloadError.http(status))
            } else {
                self.finish(taskID, tempFile: moved ? staged : nil,
                            error: moved ? nil : DownloadError.cannotWrite)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in self.setProgress(taskID, value) }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskID = task.taskIdentifier
        Task { @MainActor in self.finish(taskID, tempFile: nil, error: error) }
    }
}

extension DownloadManager {
    /// Per i download che non passano da URLSession (i segmenti HLS uniti a mano).
    func beginManual(id: String, title: String, fileName: String) {
        jobs[id] = Job(id: id, title: title, progress: 0, fileName: fileName)
    }

    func updateManual(id: String, progress value: Double) {
        guard var job = jobs[id] else { return }
        job.progress = min(max(value, 0), 1)
        jobs[id] = job
    }

    func endManual(id: String) {
        jobs[id] = nil
    }
}
