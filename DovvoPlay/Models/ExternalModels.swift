import Foundation

public struct SpotifyItem: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let thumbnailUrl: String
    public let url: String
    public let duration: TimeInterval

    public init(
        id: String,
        title: String,
        artist: String,
        thumbnailUrl: String,
        url: String,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.thumbnailUrl = thumbnailUrl
        self.url = url
        self.duration = duration
    }

    public var artworkUrl: String { thumbnailUrl }
    public var permalinkUrl: String { url }
    public var user: String { author }
}

public struct SpotifyPlaylistInfo {
    public let title: String
    public let author: String
    public let thumbnailUrl: String
    public let tracks: [SpotifyItem]

    public init(title: String, author: String, thumbnailUrl: String, tracks: [SpotifyItem]) {
        self.title = title
        self.author = author
        self.thumbnailUrl = thumbnailUrl
        self.tracks = tracks
    }
}

public struct SoundCloudTrack: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let author: String
    public let thumbnailUrl: String
    public let url: String
    public let duration: TimeInterval

    public init(
        id: String,
        title: String,
        author: String,
        thumbnailUrl: String,
        url: String,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.thumbnailUrl = thumbnailUrl
        self.url = url
        self.duration = duration
    }

    public var artworkUrl: String { thumbnailUrl }
    public var permalinkUrl: String { url }
    public var user: String { author }
}

public struct PcDownloadTask: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let service: String
    public let status: String
    public let progress: Double
    public let downloadUrl: String?

    public init(
        id: String,
        title: String,
        artist: String,
        service: String,
        status: String,
        progress: Double = 0.0,
        downloadUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.service = service
        self.status = status
        self.progress = progress
        self.downloadUrl = downloadUrl
    }
}

public struct SyncProgress: Codable, Equatable {
    public let active: Bool
    public let phase: String
    public let playlist: String
    public let total: Int
    public let alreadyOnPhone: Int
    public let toDownload: Int
    public let downloaded: Int
    public let toSend: Int
    public let index: Int
    public let received: Int
    public let failed: Int
    public let failedSend: Int
    public let retryRound: Int
    public let maxRetries: Int
    public let isSingleTrack: Bool
    public let playlistCreated: Bool
    public let current: String
    public let percent: Double
    public let error: String?
    public let missingTitles: [String]

    public init(
        active: Bool = false,
        phase: String = "",
        playlist: String = "",
        total: Int = 0,
        alreadyOnPhone: Int = 0,
        toDownload: Int = 0,
        downloaded: Int = 0,
        toSend: Int = 0,
        index: Int = 0,
        received: Int = 0,
        failed: Int = 0,
        failedSend: Int = 0,
        retryRound: Int = 0,
        maxRetries: Int = 3,
        isSingleTrack: Bool = false,
        playlistCreated: Bool = false,
        current: String = "",
        percent: Double = 0.0,
        error: String? = nil,
        missingTitles: [String] = []
    ) {
        self.active = active
        self.phase = phase
        self.playlist = playlist
        self.total = total
        self.alreadyOnPhone = alreadyOnPhone
        self.toDownload = toDownload
        self.downloaded = downloaded
        self.toSend = toSend
        self.index = index
        self.received = received
        self.failed = failed
        self.failedSend = failedSend
        self.retryRound = retryRound
        self.maxRetries = maxRetries
        self.isSingleTrack = isSingleTrack
        self.playlistCreated = playlistCreated
        self.current = current
        self.percent = percent
        self.error = error
        self.missingTitles = missingTitles
    }

    public var counter: String {
        if phase == "download" {
            return "\(downloaded)/\(toDownload)"
        }
        if toSend > 0 {
            return "\(received)/\(toSend)"
        }
        return "\(received)/\(toDownload)"
    }

    public var counterLabel: String {
        return phase == "download" ? "scaricate" : "ricevute"
    }

    public var isDone: Bool { phase == "completato" }
    public var hasError: Bool { phase == "errore" }

    public var progress: Double {
        return percent > 1.0 ? percent / 100.0 : percent
    }

    public var currentTask: String? {
        return current.isEmpty ? phaseLabel : current
    }

    public var currentTrack: Int {
        return downloaded
    }

    public var totalTracks: Int {
        return total
    }

    public var phaseLabel: String {
        switch phase {
        case "in_coda":
            return "In coda..."
        case "analisi":
            return "Leggo la playlist..."
        case "confronto":
            return "Confronto con la tua libreria..."
        case "download":
            return "Scarico i brani mancanti sul PC"
        case "invio":
            return "Invio i brani al telefono"
        case "ritenta":
            return "Ritento gli invii non riusciti (\(retryRound)/\(maxRetries))"
        case "completato":
            return "Sincronizzazione completata"
        case "errore":
            return "Errore nella sincronizzazione"
        default:
            return phase
        }
    }
}

public struct AppReleaseInfo: Identifiable, Equatable {
    public var id: String { tagName }
    public let tagName: String
    public let name: String
    public let body: String
    public let ipaDownloadUrl: String?
    public let ipaSize: Int
    public let publishedAt: Date?
    public let htmlUrl: String
    public let isNewer: Bool

    public var cleanVersion: String {
        if tagName.hasPrefix("v") {
            return String(tagName.dropFirst())
        }
        return tagName
    }
}
