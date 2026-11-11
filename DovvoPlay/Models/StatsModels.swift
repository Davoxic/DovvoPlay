import Foundation
import SwiftUI

public enum ListenTier: String, Codable {
    case skipped    // 0% - 15%
    case brief      // 15% - 35%
    case half       // 35% - 95%
    case completed  // 95% - 100%
}

public struct TrackStat: Identifiable, Codable, Equatable {
    public var id: String { trackId }
    public let trackId: String
    public var title: String
    public var artist: String
    public var thumbnailUrl: String?
    public var playCount: Int
    public var completedCount: Int
    public var halfCount: Int
    public var briefCount: Int
    public var skipCount: Int
    public var repeatCount: Int
    public var totalDurationSeconds: Int
    public var lastPlayedAt: Date
    public var firstPlayedAt: Date

    public init(
        trackId: String,
        title: String,
        artist: String,
        thumbnailUrl: String? = nil,
        playCount: Int = 0,
        completedCount: Int = 0,
        halfCount: Int = 0,
        briefCount: Int = 0,
        skipCount: Int = 0,
        repeatCount: Int = 0,
        totalDurationSeconds: Int = 0,
        lastPlayedAt: Date = Date(),
        firstPlayedAt: Date = Date()
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.thumbnailUrl = thumbnailUrl
        self.playCount = playCount
        self.completedCount = completedCount
        self.halfCount = halfCount
        self.briefCount = briefCount
        self.skipCount = skipCount
        self.repeatCount = repeatCount
        self.totalDurationSeconds = totalDurationSeconds
        self.lastPlayedAt = lastPlayedAt
        self.firstPlayedAt = firstPlayedAt
    }
}

public struct DayStat: Identifiable, Codable, Equatable {
    public var id: String { dateKey }
    public let dateKey: String // YYYY-MM-DD
    public var listeningSeconds: Int
    public var skipsCount: Int
    public var briefCount: Int
    public var halfCount: Int
    public var completedCount: Int
    public var trackPlays: [String: Int]
    public var trackSkips: [String: Int]

    public init(
        dateKey: String,
        listeningSeconds: Int = 0,
        skipsCount: Int = 0,
        briefCount: Int = 0,
        halfCount: Int = 0,
        completedCount: Int = 0,
        trackPlays: [String: Int] = [:],
        trackSkips: [String: Int] = [:]
    ) {
        self.dateKey = dateKey
        self.listeningSeconds = listeningSeconds
        self.skipsCount = skipsCount
        self.briefCount = briefCount
        self.halfCount = halfCount
        self.completedCount = completedCount
        self.trackPlays = trackPlays
        self.trackSkips = trackSkips
    }
}

public struct DailyMoodOutcome: Equatable {
    public let title: String
    public let message: String
    public let systemImage: String
    public let color: Color
    public let isPositive: Bool

    public init(title: String, message: String, systemImage: String, color: Color, isPositive: Bool) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.color = color
        self.isPositive = isPositive
    }
}

public struct PeriodStat: Equatable {
    public let label: String
    public let listeningSeconds: Int
    public let skipsCount: Int
    public let briefCount: Int
    public let halfCount: Int
    public let completedCount: Int
    public let trackPlays: [String: Int]
    public let trackSkips: [String: Int]

    public var totalInteractions: Int {
        return skipsCount + briefCount + halfCount + completedCount
    }

    public func getMood() -> DailyMoodOutcome {
        if totalInteractions == 0 {
            return DailyMoodOutcome(
                title: "Nessun ascolto registrato",
                message: "Nessun dato registrato per questo intervallo di tempo.",
                systemImage: "headphones",
                color: Color.blue,
                isPositive: true
            )
        }
        let realListening = halfCount + completedCount
        if skipsCount > realListening {
            return DailyMoodOutcome(
                title: "Non te n'è andata bene una! 🙃",
                message: "In questo intervallo gli skip superano i brani ascoltati.",
                systemImage: "hand.thumbsdown.fill",
                color: Color.red,
                isPositive: false
            )
        } else {
            return DailyMoodOutcome(
                title: "Tutto a gonfie vele, grande! 🔥",
                message: "Sessioni di ascolto piene e pochissimi brani skippati!",
                systemImage: "flame.fill",
                color: Color.yellow,
                isPositive: true
            )
        }
    }
}
