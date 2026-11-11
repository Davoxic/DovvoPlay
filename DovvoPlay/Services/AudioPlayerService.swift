import Foundation
import AVFoundation
import MediaPlayer
import Combine

public enum PlayerLoopMode: String, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case off
    case all
    case one
}

public enum ShuffleMode: String, CaseIterable, Identifiable {
    public var id: String { rawValue }

    case off = "off"
    case magic = "magic"
    case standard = "standard"
    case mostPlayed = "mostPlayed"
    case leastPlayed = "leastPlayed"
    case mediumPlayed = "mediumPlayed"
    case recent = "recent"

    public var label: String {
        switch self {
        case .off: return "Disattivo"
        case .magic: return "Magico"
        case .standard: return "Casuale 100%"
        case .mostPlayed: return "Hit Parade"
        case .leastPlayed: return "Riscopri"
        case .mediumPlayed: return "Equilibrato"
        case .recent: return "Freschi & Recenti"
        }
    }

    public var systemImage: String {
        switch self {
        case .off: return "shuffle"
        case .magic: return "sparkles"
        case .standard: return "shuffle"
        case .mostPlayed: return "flame.fill"
        case .leastPlayed: return "safari.fill"
        case .mediumPlayed: return "scale.3d"
        case .recent: return "clock.arrow.circlepath"
        }
    }

    public var modeDescription: String {
        switch self {
        case .off: return "Ordine sequenziale"
        case .magic: return "Mix intelligente tra preferite, medie e da riscoprire"
        case .standard: return "Mescola tutti i brani casualmente"
        case .mostPlayed: return "Priorità ai brani più ascoltati e ripetuti"
        case .leastPlayed: return "Ascolta le canzoni mai o meno ascoltate"
        case .mediumPlayed: return "Canzoni nella fascia media di ascolto"
        case .recent: return "Brani recenti o aggiunti ultimamente"
        }
    }
}

public class AudioPlayerService: NSObject, ObservableObject {
    public static let shared = AudioPlayerService()

    private var player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var secondTicker: Timer?
    private var playRequestId: Int = 0
    private var trackListenStartTime: Date?
    private var accumulatedListenSeconds: Double = 0

    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var queue: [Track] = []
    @Published public private(set) var originalQueue: [Track] = []
    @Published public private(set) var currentIndex: Int = -1
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var position: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var loopMode: PlayerLoopMode = .off
    @Published public private(set) var shuffleMode: ShuffleMode = .off
    @Published public private(set) var lastErrorMessage: String?

    public var isShuffle: Bool { shuffleMode != .off }
    public var hasNext: Bool { currentIndex >= 0 && currentIndex < queue.count - 1 }
    public var hasPrevious: Bool { currentIndex > 0 }

    public var nextTrack: Track? {
        guard !queue.isEmpty else { return nil }
        if currentIndex >= 0 && currentIndex < queue.count - 1 {
            return queue[currentIndex + 1]
        }
        if loopMode == .all { return queue.first }
        return nil
    }

    public var previousTrack: Track? {
        guard !queue.isEmpty else { return nil }
        if currentIndex > 0 { return queue[currentIndex - 1] }
        if loopMode == .all { return queue.last }
        return nil
    }

    override private init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        setupTimeObserver()
        setupSecondTicker()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        secondTicker?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Errore setup AVAudioSession: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.35, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let sec = CMTimeGetSeconds(time)
            if !sec.isNaN && !sec.isInfinite {
                self.position = sec
                self.updateNowPlayingInfoPosition()
            }
        }
    }

    private func setupSecondTicker() {
        secondTicker?.invalidate()
        secondTicker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying && !self.isBuffering, let track = self.currentTrack {
                self.accumulatedListenSeconds += 1.0
                StatsService.shared.addListeningSeconds(track: track, seconds: 1)
            }
        }
    }

    // --- PLAYBACK CONTROLS ---

    public func play(track: Track, from queue: [Track]? = nil) {
        playTrack(track, newQueue: queue)
    }

    public func playTrack(_ track: Track, newQueue: [Track]? = nil) {
        playRequestId += 1
        let currentRequestId = playRequestId

        if currentTrack != nil {
            recordCurrentTrackStats()
        }
        accumulatedListenSeconds = 0

        if let newQueue = newQueue {
            self.originalQueue = newQueue
            self.queue = newQueue
            if shuffleMode != .off {
                applyShuffleLogic(shuffleMode, keepCurrentTrack: track)
            } else {
                self.currentIndex = self.queue.firstIndex(where: { $0.id == track.id }) ?? 0
            }
        } else if !queue.contains(where: { $0.id == track.id }) {
            queue.append(track)
            originalQueue.append(track)
            currentIndex = queue.count - 1
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        }

        self.currentTrack = track
        self.position = 0
        self.duration = track.duration > 0 ? track.duration : 0
        self.isBuffering = true
        self.lastErrorMessage = nil

        StatsService.shared.recordTrackStart(track: track)
        updateNowPlayingInfo(track: track)

        Task { @MainActor in
            do {
                var audioURL: URL?

                if track.isOnline {
                    let videoId = track.id.replacingOccurrences(of: "yt_", with: "")

                    // 1. Check local audio file
                    if let local = YouTubeService.shared.getLocalAudioFile(trackId: track.id) {
                        audioURL = local
                    }
                    // 2. Download to cache
                    else if let cached = await YouTubeService.shared.downloadToCache(videoId: videoId, title: track.title) {
                        audioURL = cached
                    }
                    // 3. Fallback playable stream
                    else if let stream = await YouTubeService.shared.getPlayableStreamUrl(videoId: videoId) {
                        audioURL = stream
                    } else {
                        throw NSError(domain: "DovvoPlay", code: 404, userInfo: [NSLocalizedDescriptionKey: "Flusso audio non disponibile."])
                    }
                } else if let localPath = track.filePath {
                    audioURL = URL(fileURLWithPath: localPath)
                } else if let streamUrl = track.streamUrl, let url = URL(string: streamUrl) {
                    audioURL = url
                }

                guard currentRequestId == self.playRequestId else { return }
                guard let targetURL = audioURL else {
                    throw NSError(domain: "DovvoPlay", code: 400, userInfo: [NSLocalizedDescriptionKey: "Percorso audio non valido."])
                }

                let playerItem = AVPlayerItem(url: targetURL)
                self.player.replaceCurrentItem(with: playerItem)

                // Read duration from item
                if let itemDuration = try? await playerItem.asset.load(.duration) {
                    let sec = CMTimeGetSeconds(itemDuration)
                    if !sec.isNaN && !sec.isInfinite && sec > 0 {
                        self.duration = sec
                    }
                }

                self.player.play()
                self.isPlaying = true
                self.isBuffering = false
                self.updateNowPlayingInfo(track: track)
            } catch {
                guard currentRequestId == self.playRequestId else { return }
                self.isBuffering = false
                self.isPlaying = false
                self.lastErrorMessage = error.localizedDescription
            }
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        player.play()
        isPlaying = true
        updateNowPlayingInfoPosition()
    }

    public func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfoPosition()
    }

    public func seek(to seconds: TimeInterval) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.position = seconds
            self?.updateNowPlayingInfoPosition()
        }
    }

    public func next() {
        if hasNext {
            currentIndex += 1
            playTrack(queue[currentIndex])
        } else if loopMode == .all && !queue.isEmpty {
            currentIndex = 0
            playTrack(queue[0])
        }
    }

    public func previous() {
        if position > 3.0 {
            seek(to: 0)
        } else if hasPrevious {
            currentIndex -= 1
            playTrack(queue[currentIndex])
        } else {
            seek(to: 0)
        }
    }

    public func playNext(_ track: Track) {
        queue.removeAll(where: { $0.id == track.id && $0.id != currentTrack?.id })
        let insertPos = currentIndex >= 0 ? min(currentIndex + 1, queue.count) : 0
        queue.insert(track, at: insertPos)
        if !originalQueue.contains(where: { $0.id == track.id }) {
            originalQueue.append(track)
        }
    }

    public func addToQueue(_ track: Track) {
        if queue.contains(where: { $0.id == track.id }) { return }
        queue.append(track)
        if !originalQueue.contains(where: { $0.id == track.id }) {
            originalQueue.append(track)
        }
    }

    public func removeFromQueue(trackId: String) {
        guard let index = queue.firstIndex(where: { $0.id == trackId }), index != currentIndex else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        }
    }

    public func toggleLoopMode() {
        switch loopMode {
        case .off: loopMode = .all
        case .all: loopMode = .one
        case .one: loopMode = .off
        }
    }

    @objc private func playerItemDidReachEnd() {
        recordCurrentTrackStats()

        if loopMode == .one {
            seek(to: 0)
            play()
        } else if hasNext {
            next()
        } else if loopMode == .all && !queue.isEmpty {
            currentIndex = 0
            playTrack(queue[0])
        } else {
            pause()
        }
    }

    private func recordCurrentTrackStats() {
        guard let track = currentTrack else { return }
        let listenedSec = accumulatedListenSeconds
        accumulatedListenSeconds = 0
        guard listenedSec > 0 else { return }

        let totalDur = duration > 0 ? duration : (track.duration > 0 ? track.duration : 0)
        var percent: Double = 0.0

        if totalDur > 0 {
            percent = (listenedSec / totalDur) * 100.0
        } else {
            if listenedSec >= 120 {
                percent = 60.0
            } else if listenedSec >= 60 {
                percent = 40.0
            } else if listenedSec >= 20 {
                percent = 25.0
            } else {
                percent = 5.0
            }
        }
        StatsService.shared.recordTrackByPercentage(track: track, percentage: min(max(percent, 0.0), 100.0))
    }

    // --- SHUFFLE MODES ---

    public func setShuffleMode(_ mode: ShuffleMode, baseList: [Track]? = nil) {
        self.shuffleMode = mode
        if let baseList = baseList, !baseList.isEmpty {
            self.originalQueue = baseList
            self.queue = baseList
        }

        if mode == .off {
            if !originalQueue.isEmpty {
                self.queue = originalQueue
                if let cur = currentTrack {
                    self.currentIndex = self.queue.firstIndex(where: { $0.id == cur.id }) ?? 0
                }
            }
        } else {
            applyShuffleLogic(mode, keepCurrentTrack: currentTrack)
        }
    }

    public func cycleShuffleMode() {
        let all = ShuffleMode.allCases
        guard let idx = all.firstIndex(of: shuffleMode) else { return }
        let nextIdx = (idx + 1) % all.count
        setShuffleMode(all[nextIdx])
    }

    public func toggleShuffle() {
        if shuffleMode == .off {
            setShuffleMode(.magic)
        } else {
            setShuffleMode(.off)
        }
    }

    private func applyShuffleLogic(_ mode: ShuffleMode, keepCurrentTrack: Track?) {
        guard queue.count > 1 else { return }
        let pool = !originalQueue.isEmpty ? originalQueue : queue
        let stats = StatsService.shared

        var result: [Track] = []

        switch mode {
        case .off:
            result = pool
        case .standard:
            result = pool.shuffled()
        case .magic:
            let sortedByPlays = pool.sorted { stats.getPlayCount($0.id) > stats.getPlayCount($1.id) }
            let count = sortedByPlays.count
            let topCut = max(1, Int(ceil(Double(count) * 0.25)))
            let medCut = min(count, max(topCut, Int(ceil(Double(count) * 0.70))))

            var topTier = Array(sortedByPlays[0..<topCut]).shuffled()
            var medTier = Array(sortedByPlays[topCut..<medCut]).shuffled()
            var leastTier = Array(sortedByPlays[medCut..<count]).shuffled()

            var combined: [Track] = []
            while !topTier.isEmpty || !medTier.isEmpty || !leastTier.isEmpty {
                if !topTier.isEmpty { combined.append(topTier.removeLast()) }
                if !medTier.isEmpty { combined.append(medTier.removeLast()) }
                if !leastTier.isEmpty { combined.append(leastTier.removeLast()) }
                if !medTier.isEmpty { combined.append(medTier.removeLast()) }
            }
            result = smoothArtistCollisions(combined)
        case .mostPlayed:
            result = pool.sorted {
                let aScore = stats.getPlayCount($0.id) * 10 + stats.getRepeatCount($0.id) * 5 + Int.random(in: 0..<5)
                let bScore = stats.getPlayCount($1.id) * 10 + stats.getRepeatCount($1.id) * 5 + Int.random(in: 0..<5)
                return aScore > bScore
            }
        case .leastPlayed:
            result = pool.sorted {
                let aScore = stats.getPlayCount($0.id) * 10 + Int.random(in: 0..<4)
                let bScore = stats.getPlayCount($1.id) * 10 + Int.random(in: 0..<4)
                return aScore < bScore
            }
        case .mediumPlayed:
            let sorted = pool.sorted { stats.getPlayCount($0.id) > stats.getPlayCount($1.id) }
            let start = Int(Double(sorted.count) * 0.20)
            let end = Int(Double(sorted.count) * 0.80)
            let middle = Array(sorted[min(start, sorted.count)..<min(end, sorted.count)]).shuffled()
            let remaining = pool.filter { !middle.contains($0) }.shuffled()
            result = middle + remaining
        case .recent:
            var list = pool.sorted {
                let timeA = stats.getStat($0.id)?.lastPlayedAt ?? $0.addedAt
                let timeB = stats.getStat($1.id)?.lastPlayedAt ?? $1.addedAt
                return timeA > timeB
            }
            if list.count > 1 {
                for i in stride(from: 0, to: list.count - 1, by: 2) {
                    if Bool.random() {
                        list.swapAt(i, i + 1)
                    }
                }
            }
            result = list
        }

        if let keep = keepCurrentTrack {
            result.removeAll(where: { $0.id == keep.id })
            result.insert(keep, at: 0)
            self.currentIndex = 0
        }

        self.queue = result
    }

    private func smoothArtistCollisions(_ list: [Track]) -> [Track] {
        guard list.count > 2 else { return list }
        var smoothed = [list[0]]
        var remaining = Array(list.dropFirst())

        while !remaining.isEmpty {
            let lastArtist = smoothed.last!.displayArtist.lowercased()
            if let foundIdx = remaining.firstIndex(where: { $0.displayArtist.lowercased() != lastArtist }) {
                smoothed.append(remaining.remove(at: foundIdx))
            } else {
                smoothed.append(contentsOf: remaining)
                break
            }
        }
        return smoothed
    }

    // --- LOCK SCREEN / NOW PLAYING ---

    private func updateNowPlayingInfo(track: Track) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayTitle,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPMediaItemPropertyAlbumTitle: !track.album.isEmpty ? track.album : (track.isOnline ? "YouTube" : "DovvoPlay"),
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let thumb = track.thumbnailUrl, !thumb.isEmpty {
            if thumb.hasPrefix("http"), let url = URL(string: thumb) {
                Task {
                    if let (data, _) = try? await URLSession.shared.data(from: url),
                       let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        updated[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                    }
                }
            } else {
                let cleanPath = thumb.replacingOccurrences(of: "file://", with: "")
                if let image = UIImage(contentsOfFile: cleanPath) {
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingInfoPosition() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
