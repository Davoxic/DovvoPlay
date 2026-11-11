import Foundation

public struct YouTubeTrack: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let author: String
    public let duration: TimeInterval
    public let thumbnailUrl: String
    public let url: String

    public init(
        id: String,
        title: String,
        author: String,
        duration: TimeInterval,
        thumbnailUrl: String,
        url: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.thumbnailUrl = thumbnailUrl
        self.url = url
    }

    public var formattedDuration: String {
        let sec = Int(duration.rounded())
        if sec <= 0 { return "--:--" }
        let mins = sec / 60
        let rem = sec % 60
        return String(format: "%d:%02d", mins, rem)
    }

    public func toTrack(streamUrl: String? = nil) -> Track {
        return Track(
            id: "yt_\(id)",
            title: title,
            artist: author,
            album: "YouTube",
            durationMs: Int(duration * 1000),
            isOnline: true,
            streamUrl: streamUrl,
            thumbnailUrl: thumbnailUrl
        )
    }
}
