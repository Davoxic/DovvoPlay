import Foundation

public struct Playlist: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var trackIds: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var coverPath: String?

    public init(
        id: String = "pl_\(Int(Date().timeIntervalSince1970 * 1000))",
        name: String,
        trackIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        coverPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.trackIds = trackIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.coverPath = coverPath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case trackIds
        case createdAt
        case updatedAt
        case coverPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "pl_\(Int(Date().timeIntervalSince1970 * 1000))"
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Nuova Playlist"
        self.trackIds = try container.decodeIfPresent([String].self, forKey: .trackIds) ?? []
        self.coverPath = try container.decodeIfPresent(String.self, forKey: .coverPath)

        if let cStr = try container.decodeIfPresent(String.self, forKey: .createdAt),
           let d = ISO8601DateFormatter().date(from: cStr) {
            self.createdAt = d
        } else {
            self.createdAt = Date()
        }

        if let uStr = try container.decodeIfPresent(String.self, forKey: .updatedAt),
           let d = ISO8601DateFormatter().date(from: uStr) {
            self.updatedAt = d
        } else {
            self.updatedAt = Date()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(trackIds, forKey: .trackIds)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        try container.encode(ISO8601DateFormatter().string(from: updatedAt), forKey: .updatedAt)
        try container.encodeIfPresent(coverPath, forKey: .coverPath)
    }

    public func copyWith(
        id: String? = nil,
        name: String? = nil,
        trackIds: [String]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        coverPath: String? = nil
    ) -> Playlist {
        return Playlist(
            id: id ?? self.id,
            name: name ?? self.name,
            trackIds: trackIds ?? self.trackIds,
            createdAt: createdAt ?? self.createdAt,
            updatedAt: updatedAt ?? self.updatedAt,
            coverPath: coverPath ?? self.coverPath
        )
    }
}
