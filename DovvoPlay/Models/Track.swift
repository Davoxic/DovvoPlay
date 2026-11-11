import Foundation

public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var artist: String
    public var album: String
    public var durationMs: Int
    public var filePath: String?
    public var isOnline: Bool
    public var streamUrl: String?
    public var thumbnailUrl: String?
    public var fileSize: Int?
    public var bpm: Double?
    public var addedAt: Date

    public init(
        id: String,
        title: String,
        artist: String,
        album: String = "",
        durationMs: Int = 0,
        filePath: String? = nil,
        isOnline: Bool = false,
        streamUrl: String? = nil,
        thumbnailUrl: String? = nil,
        fileSize: Int? = nil,
        bpm: Double? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.filePath = filePath
        self.isOnline = isOnline
        self.streamUrl = streamUrl
        self.thumbnailUrl = thumbnailUrl
        self.fileSize = fileSize
        self.bpm = bpm
        self.addedAt = addedAt
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Traccia sconosciuta" : trimmed
    }

    public var displayArtist: String {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Artista sconosciuto" : trimmed
    }

    public var duration: TimeInterval {
        return TimeInterval(durationMs) / 1000.0
    }

    public var formattedDuration: String {
        let seconds = Int(duration.rounded())
        if seconds <= 0 { return "--:--" }
        let mins = seconds / 60
        let remSecs = seconds % 60
        return String(format: "%d:%02d", mins, remSecs)
    }

    public var fileURL: URL? {
        guard let filePath = filePath, !filePath.isEmpty else { return nil }
        if filePath.hasPrefix("file://") {
            return URL(string: filePath)
        }
        return URL(fileURLWithPath: filePath)
    }

    public var fileName: String {
        if let filePath = filePath {
            return (filePath as NSString).lastPathComponent
        }
        return (id as NSString).lastPathComponent
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case artist
        case album
        case durationMs = "duration_ms"
        case durationSec = "duration"
        case filePath
        case isOnline
        case streamUrl
        case thumbnailUrl
        case fileSize
        case bpm
        case addedAt
        case file
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let resolvedId = try container.decodeIfPresent(String.self, forKey: .id)
            ?? (try container.decodeIfPresent(String.self, forKey: .file))
            ?? UUID().uuidString
        self.id = resolvedId

        let resolvedTitle = try container.decodeIfPresent(String.self, forKey: .title)
            ?? (try container.decodeIfPresent(String.self, forKey: .name))
            ?? ""
        self.title = resolvedTitle

        self.artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
        self.album = try container.decodeIfPresent(String.self, forKey: .album) ?? ""

        if let ms = try container.decodeIfPresent(Int.self, forKey: .durationMs) {
            self.durationMs = ms
        } else if let sec = try container.decodeIfPresent(Double.self, forKey: .durationSec) {
            self.durationMs = Int(sec * 1000.0)
        } else {
            self.durationMs = 0
        }

        self.filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        self.isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
        self.streamUrl = try container.decodeIfPresent(String.self, forKey: .streamUrl)
        self.thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        self.fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        self.bpm = try container.decodeIfPresent(Double.self, forKey: .bpm)

        if let dateStr = try container.decodeIfPresent(String.self, forKey: .addedAt),
           let parsedDate = ISO8601DateFormatter().date(from: dateStr) {
            self.addedAt = parsedDate
        } else {
            self.addedAt = Date()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encode(album, forKey: .album)
        try container.encode(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(streamUrl, forKey: .streamUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(bpm, forKey: .bpm)
        try container.encode(ISO8601DateFormatter().string(from: addedAt), forKey: .addedAt)
        try container.encode(fileName, forKey: .file)
    }

    public func copyWith(
        id: String? = nil,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        durationMs: Int? = nil,
        filePath: String? = nil,
        isOnline: Bool? = nil,
        streamUrl: String? = nil,
        thumbnailUrl: String? = nil,
        fileSize: Int? = nil,
        bpm: Double? = nil,
        addedAt: Date? = nil
    ) -> Track {
        return Track(
            id: id ?? self.id,
            title: title ?? self.title,
            artist: artist ?? self.artist,
            album: album ?? self.album,
            durationMs: durationMs ?? self.durationMs,
            filePath: filePath ?? self.filePath,
            isOnline: isOnline ?? self.isOnline,
            streamUrl: streamUrl ?? self.streamUrl,
            thumbnailUrl: thumbnailUrl ?? self.thumbnailUrl,
            fileSize: fileSize ?? self.fileSize,
            bpm: bpm ?? self.bpm,
            addedAt: addedAt ?? self.addedAt
        )
    }
}
