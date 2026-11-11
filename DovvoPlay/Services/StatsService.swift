import Foundation
import SwiftUI

public class StatsService: ObservableObject {
    public static let shared = StatsService()

    private let prefsKey = "dovvoplay_track_stats_v3"
    private let daysKey = "dovvoplay_daily_stats_v3"

    @Published public private(set) var stats: [String: TrackStat] = [:]
    @Published public private(set) var days: [String: DayStat] = [:]
    @Published public private(set) var isLoaded: Bool = false

    private var lastPlayedTrackId: String?
    private var secondsSinceLastSave: Int = 0

    private init() {
        loadStats()
    }

    private func getTodayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    public var todayStat: DayStat {
        let key = getTodayKey()
        if let existing = days[key] {
            return existing
        }
        let newDay = DayStat(dateKey: key)
        days[key] = newDay
        return newDay
    }

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: prefsKey),
           let decoded = try? JSONDecoder().decode([String: TrackStat].self, from: data) {
            self.stats = decoded
        }

        if let daysData = UserDefaults.standard.data(forKey: daysKey),
           let decodedDays = try? JSONDecoder().decode([String: DayStat].self, from: daysData) {
            self.days = decodedDays
        }

        self.isLoaded = true
    }

    public func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: prefsKey)
        }
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: daysKey)
        }
    }

    public func saveAndNotify() {
        saveStats()
        objectWillChange.send()
    }

    public func restoreOrMergeStat(_ imported: TrackStat) {
        if var existing = stats[imported.trackId] {
            existing.completedCount = max(existing.completedCount, imported.completedCount)
            existing.playCount = existing.completedCount
            existing.halfCount = max(existing.halfCount, imported.halfCount)
            existing.briefCount = max(existing.briefCount, imported.briefCount)
            existing.skipCount = max(existing.skipCount, imported.skipCount)
            existing.repeatCount = max(existing.repeatCount, imported.repeatCount)
            existing.totalDurationSeconds = max(existing.totalDurationSeconds, imported.totalDurationSeconds)
            if imported.lastPlayedAt > existing.lastPlayedAt {
                existing.lastPlayedAt = imported.lastPlayedAt
            }
            stats[imported.trackId] = existing
        } else {
            stats[imported.trackId] = imported
        }
    }

    // --- REGISTRAZIONE SECONDO PER SECONDO ---

    public func addListeningSeconds(track: Track, seconds: Int = 1) {
        guard seconds > 0 else { return }

        var stat = stats[track.id] ?? TrackStat(
            trackId: track.id,
            title: track.displayTitle,
            artist: track.displayArtist,
            thumbnailUrl: track.thumbnailUrl
        )

        stat.totalDurationSeconds += seconds
        stat.lastPlayedAt = Date()
        stats[track.id] = stat

        let key = getTodayKey()
        var today = days[key] ?? DayStat(dateKey: key)
        today.listeningSeconds += seconds
        days[key] = today

        secondsSinceLastSave += seconds
        if secondsSinceLastSave >= 6 {
            secondsSinceLastSave = 0
            saveStats()
            objectWillChange.send()
        }
    }

    // --- REGISTRAZIONE GRANULARE PERCENTUALE ---

    public func recordTrackByPercentage(track: Track, percentage: Double) {
        let now = Date()
        let key = getTodayKey()
        var today = days[key] ?? DayStat(dateKey: key)

        var stat = stats[track.id] ?? TrackStat(
            trackId: track.id,
            title: track.displayTitle,
            artist: track.displayArtist,
            thumbnailUrl: track.thumbnailUrl,
            firstPlayedAt: now,
            lastPlayedAt: now
        )

        stat.lastPlayedAt = now

        if percentage < 15.0 {
            // 0% - 15%: SKIPPATA
            stat.skipCount += 1
            today.skipsCount += 1
            today.trackSkips[track.id] = (today.trackSkips[track.id] ?? 0) + 1
        } else if percentage < 35.0 {
            // 15% - 35%: ASCOLTATA POCO
            stat.briefCount += 1
            today.briefCount += 1
        } else if percentage < 95.0 {
            // 35% - 95%: ASCOLTATA A METÀ
            stat.halfCount += 1
            today.halfCount += 1
        } else {
            // 95% - 100%: ASCOLTATA COMPLETA
            stat.completedCount += 1
            stat.playCount += 1
            today.completedCount += 1
            today.trackPlays[track.id] = (today.trackPlays[track.id] ?? 0) + 1

            if lastPlayedTrackId == track.id {
                stat.repeatCount += 1
            }
            lastPlayedTrackId = track.id
        }

        stats[track.id] = stat
        days[key] = today

        saveStats()
        objectWillChange.send()
    }

    public func recordTrackStart(track: Track) {
        if stats[track.id] == nil {
            stats[track.id] = TrackStat(
                trackId: track.id,
                title: track.displayTitle,
                artist: track.displayArtist,
                thumbnailUrl: track.thumbnailUrl
            )
        }
    }

    // --- ESITO DEL GIORNO ---

    public func getDailyMood() -> DailyMoodOutcome {
        let today = todayStat
        let total = today.skipsCount + today.briefCount + today.halfCount + today.completedCount

        if total == 0 {
            return DailyMoodOutcome(
                title: "Inizia ad ascoltare!",
                message: "Non hai ancora ascoltato canzoni oggi. Fai partire la tua musica preferita!",
                systemImage: "headphones",
                color: Color.blue,
                isPositive: true
            )
        }

        let realListening = today.halfCount + today.completedCount
        if today.skipsCount > realListening {
            return DailyMoodOutcome(
                title: "Oggi non te ne va bene una! 🙃",
                message: "La percentuale di skip è più alta di quella delle canzoni ascoltate. Prova lo Shuffle Magico o una nuova playlist!",
                systemImage: "hand.thumbsdown.fill",
                color: Color.red,
                isPositive: false
            )
        } else {
            return DailyMoodOutcome(
                title: "Oggi ti va tutto a gonfie vele, grande! 🔥",
                message: "Stai ascoltando i tuoi brani con entusiasmo e pochissimi skip. Ottima sessione musicale!",
                systemImage: "flame.fill",
                color: Color.yellow,
                isPositive: true
            )
        }
    }

    // --- PERIOD STATS ---

    public func getStatForDay(_ date: Date) -> PeriodStat {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        let day = days[key] ?? DayStat(dateKey: key)

        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMMM yyyy"
        let label = formatter.string(from: date)

        return PeriodStat(
            label: label,
            listeningSeconds: day.listeningSeconds,
            skipsCount: day.skipsCount,
            briefCount: day.briefCount,
            halfCount: day.halfCount,
            completedCount: day.completedCount,
            trackPlays: day.trackPlays,
            trackSkips: day.trackSkips
        )
    }

    public func getStatForMonth(_ year: Int, _ month: Int) -> PeriodStat {
        let prefix = String(format: "%04d-%02d", year, month)
        var totalSec = 0
        var totalSkips = 0
        var totalBrief = 0
        var totalHalf = 0
        var totalComp = 0
        var plays: [String: Int] = [:]
        var skips: [String: Int] = [:]

        for (key, day) in days where key.hasPrefix(prefix) {
            totalSec += day.listeningSeconds
            totalSkips += day.skipsCount
            totalBrief += day.briefCount
            totalHalf += day.halfCount
            totalComp += day.completedCount
            for (tid, count) in day.trackPlays {
                plays[tid] = (plays[tid] ?? 0) + count
            }
            for (tid, count) in day.trackSkips {
                skips[tid] = (skips[tid] ?? 0) + count
            }
        }

        let comps = DateComponents(year: year, month: month)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "LLLL yyyy"
        let label = formatter.string(from: Calendar.current.date(from: comps) ?? Date()).capitalized

        return PeriodStat(
            label: label,
            listeningSeconds: totalSec,
            skipsCount: totalSkips,
            briefCount: totalBrief,
            halfCount: totalHalf,
            completedCount: totalComp,
            trackPlays: plays,
            trackSkips: skips
        )
    }

    public func getStatForYear(_ year: Int) -> PeriodStat {
        let prefix = String(format: "%04d-", year)
        var totalSec = 0
        var totalSkips = 0
        var totalBrief = 0
        var totalHalf = 0
        var totalComp = 0
        var plays: [String: Int] = [:]
        var skips: [String: Int] = [:]

        for (key, day) in days where key.hasPrefix(prefix) {
            totalSec += day.listeningSeconds
            totalSkips += day.skipsCount
            totalBrief += day.briefCount
            totalHalf += day.halfCount
            totalComp += day.completedCount
            for (tid, count) in day.trackPlays {
                plays[tid] = (plays[tid] ?? 0) + count
            }
            for (tid, count) in day.trackSkips {
                skips[tid] = (skips[tid] ?? 0) + count
            }
        }

        return PeriodStat(
            label: "Anno \(year)",
            listeningSeconds: totalSec,
            skipsCount: totalSkips,
            briefCount: totalBrief,
            halfCount: totalHalf,
            completedCount: totalComp,
            trackPlays: plays,
            trackSkips: skips
        )
    }

    public func getWeeklyMinutes() -> Int {
        let cal = Calendar.current
        let now = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var totalSec = 0
        for day in days.values {
            if let d = formatter.date(from: day.dateKey), d >= weekInterval.start {
                totalSec += day.listeningSeconds
            }
        }
        return totalSec / 60
    }

    public func getWeeklyDayMinutes() -> [Int: Int] {
        // 1 (Lun) .. 7 (Dom) -> minuti
        var map: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0]
        let cal = Calendar.current
        let now = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) else { return map }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for day in days.values {
            if let d = formatter.date(from: day.dateKey), d >= weekInterval.start {
                // Calendar weekday: 1 = Sun, 2 = Mon ... 7 = Sat
                let calWeekday = cal.component(.weekday, from: d)
                let isoWeekday = calWeekday == 1 ? 7 : calWeekday - 1
                map[isoWeekday] = (map[isoWeekday] ?? 0) + (day.listeningSeconds / 60)
            }
        }
        return map
    }

    public var monthlyListeningMinutes: Int {
        let cal = Calendar.current
        let now = Date()
        guard let monthInterval = cal.dateInterval(of: .month, for: now) else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var totalSec = 0
        for day in days.values {
            if let d = formatter.date(from: day.dateKey), d >= monthInterval.start {
                totalSec += day.listeningSeconds
            }
        }
        return totalSec / 60
    }

    public var totalListeningSeconds: Int {
        return stats.values.reduce(0) { $0 + $1.totalDurationSeconds }
    }

    public var totalPlaysCount: Int {
        return stats.values.reduce(0) { $0 + $1.completedCount }
    }

    public var totalHalfCount: Int {
        return stats.values.reduce(0) { $0 + $1.halfCount }
    }

    public var totalBriefCount: Int {
        return stats.values.reduce(0) { $0 + $1.briefCount }
    }

    public var totalSkipsCount: Int {
        return stats.values.reduce(0) { $0 + $1.skipCount }
    }

    public var totalRepeatsCount: Int {
        return stats.values.reduce(0) { $0 + $1.repeatCount }
    }

    public func getStat(_ trackId: String) -> TrackStat? {
        return stats[trackId]
    }

    public func getPlayCount(_ trackId: String) -> Int {
        return stats[trackId]?.completedCount ?? 0
    }

    public func getRepeatCount(_ trackId: String) -> Int {
        return stats[trackId]?.repeatCount ?? 0
    }

    public func getSkipCount(_ trackId: String) -> Int {
        return stats[trackId]?.skipCount ?? 0
    }

    // --- CLASSIFICHE TRACCE ---

    public func getMostPlayedTracks(from library: [Track], limit: Int = 30) -> [Track] {
        return library
            .filter { getPlayCount($0.id) > 0 }
            .sorted { getPlayCount($0.id) > getPlayCount($1.id) }
            .prefix(limit)
            .map { $0 }
    }

    public func getTop5PlayedTracks(from library: [Track]) -> [Track] {
        return getMostPlayedTracks(from: library, limit: 5)
    }

    public func getMostSkippedTracks(from library: [Track], limit: Int = 30) -> [Track] {
        return library
            .filter { getSkipCount($0.id) > 0 }
            .sorted { getSkipCount($0.id) > getSkipCount($1.id) }
            .prefix(limit)
            .map { $0 }
    }

    public func getMostRepeatedTracks(from library: [Track], limit: Int = 30) -> [Track] {
        return library
            .filter { getRepeatCount($0.id) > 0 }
            .sorted { getRepeatCount($0.id) > getRepeatCount($1.id) }
            .prefix(limit)
            .map { $0 }
    }

    public func getLeastPlayedTracks(from library: [Track], limit: Int = 30) -> [Track] {
        return library
            .sorted { getPlayCount($0.id) < getPlayCount($1.id) }
            .prefix(limit)
            .map { $0 }
    }

    public func getMediumPlayedTracks(from library: [Track], limit: Int = 30) -> [Track] {
        guard library.count >= 5 else { return library }
        let sorted = library.sorted { getPlayCount($0.id) > getPlayCount($1.id) }
        let start = Int(Double(sorted.count) * 0.20)
        let end = Int(Double(sorted.count) * 0.80)
        let slice = Array(sorted[min(start, sorted.count)..<min(end, sorted.count)]).shuffled()
        return Array(slice.prefix(limit))
    }

    public func getRecentlyPlayedTracks(from library: [Track], limit: Int = 30) -> [Track] {
        return library
            .filter { stats[$0.id] != nil }
            .sorted { (stats[$0.id]?.lastPlayedAt ?? .distantPast) > (stats[$1.id]?.lastPlayedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    public var topArtist: String {
        guard !stats.isEmpty else { return "Nessun dato" }
        var artistCounts: [String: Int] = [:]
        for s in stats.values {
            let a = s.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty && a != "Artista sconosciuto" {
                artistCounts[a] = (artistCounts[a] ?? 0) + s.completedCount
            }
        }
        guard !artistCounts.isEmpty else { return "Nessun dato" }
        return artistCounts.sorted(by: { $0.value > $1.value }).first?.key ?? "Nessun dato"
    }

    public func formatDurationSummary() -> String {
        let sec = totalListeningSeconds
        if sec < 60 { return "\(sec) sec" }
        let minutes = sec / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remMin = minutes % 60
        return "\(hours)h \(remMin)m"
    }

    public func resetAllStats() {
        stats.removeAll()
        days.removeAll()
        lastPlayedTrackId = nil
        secondsSinceLastSave = 0
        UserDefaults.standard.removeObject(forKey: prefsKey)
        UserDefaults.standard.removeObject(forKey: daysKey)
        objectWillChange.send()
    }
}
