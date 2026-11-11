import Foundation
import Combine

public enum DownloadJobKind: String, Codable {
    case playlist
    case single
}

public enum DownloadJobStatus: String, Codable {
    case waiting
    case inProgress
    case completed
    case error
    case cancelled

    public var label: String {
        switch self {
        case .waiting: return "In attesa"
        case .inProgress: return "In corso"
        case .completed: return "Completato"
        case .error: return "Errore"
        case .cancelled: return "Annullato"
        }
    }
}

public class DownloadJob: Identifiable, ObservableObject {
    public let id: String
    public let kind: DownloadJobKind
    public let url: String
    public let label: String
    public let createPlaylist: Bool
    public let addedAt: Date

    @Published public var status: DownloadJobStatus
    @Published public var error: String?
    @Published public var received: Int
    @Published public var total: Int

    public init(
        id: String = "job_\(Int(Date().timeIntervalSince1970 * 1000))",
        kind: DownloadJobKind = .single,
        url: String,
        label: String,
        createPlaylist: Bool = false,
        addedAt: Date = Date(),
        status: DownloadJobStatus = .waiting,
        error: String? = nil,
        received: Int = 0,
        total: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.label = label
        self.createPlaylist = createPlaylist
        self.addedAt = addedAt
        self.status = status
        self.error = error
        self.received = received
        self.total = total
    }

    public var isDone: Bool {
        return status == .completed || status == .error || status == .cancelled
    }

    public var statusDescription: String {
        switch status {
        case .waiting:
            return "In attesa"
        case .inProgress:
            return total > 0 ? "In corso · \(received)/\(total)" : "In corso"
        case .completed:
            return total > 0 ? "Completato · \(received)/\(total)" : "Completato"
        case .error:
            return error ?? "Errore"
        case .cancelled:
            return "Annullato"
        }
    }
}

public class DownloadQueueService: ObservableObject {
    public static let shared = DownloadQueueService()

    @Published public private(set) var jobs: [DownloadJob] = []
    @Published public private(set) var isWorking: Bool = false

    public var pendingCount: Int {
        jobs.filter { $0.status == .waiting }.count
    }

    public var current: DownloadJob? {
        jobs.first(where: { $0.status == .inProgress })
    }

    private init() {}

    @discardableResult
    public func enqueue(
        url: String,
        label: String,
        kind: DownloadJobKind = .single,
        createPlaylist: Bool = false
    ) -> DownloadJob {
        let job = DownloadJob(
            kind: kind,
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            label: label,
            createPlaylist: createPlaylist
        )
        jobs.append(job)
        pump()
        return job
    }

    public func remove(id: String) {
        guard let idx = jobs.firstIndex(where: { $0.id == id }), jobs[idx].status != .inProgress else { return }
        jobs.remove(at: idx)
    }

    public func clearDone() {
        jobs.removeAll(where: { $0.isDone })
    }

    private func pump() {
        guard !isWorking else { return }
        isWorking = true

        Task {
            while let job = jobs.first(where: { $0.status == .waiting }) {
                await MainActor.run {
                    job.status = .inProgress
                }

                let sync = PcSyncService.shared
                let started = await sync.startPlaylistSync(playlistUrl: job.url, createPlaylist: job.createPlaylist)

                if !started {
                    await MainActor.run {
                        job.status = .error
                        job.error = "Il PC non ha accettato la richiesta"
                    }
                    continue
                }

                let deadline = Date().addingTimeInterval(7200) // 2 hours safety
                while Date() < deadline {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    let p = sync.syncProgress
                    if let p = p {
                        await MainActor.run {
                            job.received = p.received
                            job.total = p.toSend > 0 ? p.toSend : p.toDownload
                        }
                    }
                    if p == nil || p?.active == false { break }
                }

                let finalProgress = sync.syncProgress
                await MainActor.run {
                    if let f = finalProgress, f.hasError {
                        job.status = .error
                        job.error = f.error
                    } else {
                        job.status = .completed
                        if let f = finalProgress {
                            job.received = f.received
                            job.total = f.toSend > 0 ? f.toSend : f.toDownload
                        }
                    }
                }
            }

            await MainActor.run {
                self.isWorking = false
            }
        }
    }
}
