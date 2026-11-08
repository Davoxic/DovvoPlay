import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Combine

enum RepeatMode: String, CaseIterable {
    case off, all, one
    var symbol: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Motore di riproduzione: coda, shuffle, repeat, lock screen, interruzioni.
final class PlayerEngine: NSObject, ObservableObject {

    static let shared = PlayerEngine()

    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published private(set) var artwork: UIImage?
    @Published private(set) var errorMessage: String?
    @Published var shuffle: Bool = false {
        didSet {
            UserDefaults.standard.set(shuffle, forKey: "shuffle")
            rebuildOrder(keepingCurrent: true)
        }
    }
    @Published var repeatMode: RepeatMode = .off {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode") }
    }

    private var player: AVAudioPlayer?
    private var ticker: Timer?
    private var order: [Int] = []
    private var orderPos: Int = -1
    private var consecutiveFailures = 0
    private var isSeeking = false

    var current: Track? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }
    var hasTrack: Bool { current != nil }
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
    var upNext: [Track] {
        guard orderPos >= 0, orderPos + 1 < order.count else { return [] }
        return order[(orderPos + 1)...].compactMap { queue.indices.contains($0) ? queue[$0] : nil }
    }

    private override init() {
        super.init()
        shuffle = UserDefaults.standard.bool(forKey: "shuffle")
        if let raw = UserDefaults.standard.string(forKey: "repeatMode"), let m = RepeatMode(rawValue: raw) {
            repeatMode = m
        }
        configureSession()
        configureRemoteCommands()
        observeNotifications()
    }

    // MARK: - sessione audio

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
        } catch {
            errorMessage = "Sessione audio non disponibile"
        }
    }

    private func activateSession(_ active: Bool) {
        try? AVAudioSession.sharedInstance().setActive(active, options: active ? [] : [.notifyOthersOnDeactivation])
    }

    private func observeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            if let optRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        if reason == .oldDeviceUnavailable { pause() }
    }

    // MARK: - coda

    /// Avvia una lista di brani partendo da quello indicato.
    func play(tracks: [Track], startAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        queue = tracks
        let safeIndex = tracks.indices.contains(index) ? index : 0
        rebuildOrder(startingAt: safeIndex)
        consecutiveFailures = 0
        load(index: safeIndex, autoplay: true)
    }

    func playShuffled(tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        shuffle = true
        let start = Int.random(in: 0..<tracks.count)
        play(tracks: tracks, startAt: start)
    }

    func appendToQueue(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        if queue.isEmpty {
            play(tracks: tracks, startAt: 0)
            return
        }
        let startCount = queue.count
        queue.append(contentsOf: tracks)
        order.append(contentsOf: Array(startCount..<queue.count))
    }

    func playNext(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        if queue.isEmpty {
            play(tracks: tracks, startAt: 0)
            return
        }
        let startCount = queue.count
        queue.append(contentsOf: tracks)
        let newIndices = Array(startCount..<queue.count)
        let insertAt = min(orderPos + 1, order.count)
        order.insert(contentsOf: newIndices, at: insertAt)
    }

    private func rebuildOrder(startingAt index: Int) {
        let all = Array(queue.indices)
        if shuffle {
            var rest = all.filter { $0 != index }
            rest.shuffle()
            order = [index] + rest
            orderPos = 0
        } else {
            order = all
            orderPos = index
        }
    }

    private func rebuildOrder(keepingCurrent: Bool) {
        guard !queue.isEmpty else { order = []; orderPos = -1; return }
        let cur = queue.indices.contains(currentIndex) ? currentIndex : 0
        rebuildOrder(startingAt: cur)
        if !keepingCurrent { orderPos = 0 }
    }

    // MARK: - caricamento e controlli

    private func load(index: Int, autoplay: Bool) {
        guard queue.indices.contains(index) else { return }
        let track = queue[index]
        guard FileManager.default.fileExists(atPath: track.url.path) else {
            handleLoadFailure(track: track, autoplay: autoplay)
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: track.url)
            p.delegate = self
            p.prepareToPlay()
            player?.stop()
            player = p
            currentIndex = index
            if let pos = order.firstIndex(of: index) { orderPos = pos }
            duration = p.duration > 0 ? p.duration : track.duration
            currentTime = 0
            artwork = ArtworkStore.image(for: track)
            consecutiveFailures = 0
            errorMessage = nil
            if autoplay {
                play()
            } else {
                updateNowPlaying()
            }
            saveState()
        } catch {
            handleLoadFailure(track: track, autoplay: autoplay)
        }
    }

    private func handleLoadFailure(track: Track, autoplay: Bool) {
        consecutiveFailures += 1
        errorMessage = "Impossibile riprodurre \"\(track.displayTitle)\""
        guard consecutiveFailures < min(queue.count, 20), autoplay else {
            stop()
            return
        }
        advance(auto: true)
    }

    func play() {
        guard let p = player else {
            if let first = queue.first, currentIndex < 0 {
                play(tracks: queue, startAt: queue.firstIndex(of: first) ?? 0)
            }
            return
        }
        activateSession(true)
        if p.play() {
            isPlaying = true
            startTicker()
            updateNowPlaying()
        } else {
            isPlaying = false
            errorMessage = "Riproduzione non avviata"
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTicker()
        updateNowPlaying()
        saveState()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        stopTicker()
        currentIndex = -1
        currentTime = 0
        duration = 0
        artwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        activateSession(false)
    }

    func next() { advance(auto: false) }

    func previous() {
        // come in Musica: prima di 3 secondi torna indietro, altrimenti riparte il brano
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !order.isEmpty else { return }
        var pos = orderPos - 1
        if pos < 0 {
            if repeatMode == .all { pos = order.count - 1 } else { seek(to: 0); return }
        }
        orderPos = pos
        load(index: order[pos], autoplay: true)
    }

    private func advance(auto: Bool) {
        guard !order.isEmpty else { stop(); return }
        if auto && repeatMode == .one {
            seek(to: 0)
            play()
            return
        }
        var pos = orderPos + 1
        if pos >= order.count {
            if repeatMode == .all || (!auto && repeatMode != .off) {
                pos = 0
                if shuffle { rebuildOrder(startingAt: order.first ?? 0); pos = 0 }
            } else if !auto {
                pos = 0
            } else {
                // fine coda
                pause()
                seek(to: 0)
                return
            }
        }
        orderPos = pos
        load(index: order[pos], autoplay: true)
    }

    func seek(to time: Double) {
        guard let p = player else { return }
        let t = min(max(time, 0), max(p.duration - 0.05, 0))
        p.currentTime = t
        currentTime = t
        updateNowPlaying()
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func beginScrub() { isSeeking = true }
    func endScrub(at time: Double) {
        isSeeking = false
        seek(to: time)
    }

    func toggleRepeat() { repeatMode = repeatMode.next }

    func play(track: Track, in list: [Track]) {
        let idx = list.firstIndex(of: track) ?? 0
        play(tracks: list, startAt: idx)
    }

    // MARK: - timer

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, !self.isSeeking else { return }
            self.currentTime = p.currentTime
            if !p.isPlaying && self.isPlaying {
                self.isPlaying = false
                self.updateNowPlaying()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - lock screen

    private func configureRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            self?.play(); return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous(); return .success
        }
        cc.skipForwardCommand.preferredIntervals = [15]
        cc.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: 15); return .success
        }
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -15); return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayTitle,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPMediaItemPropertyAlbumTitle: track.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let img = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - stato persistente

    private func saveState() {
        guard let track = current else { return }
        let d = UserDefaults.standard
        d.set(track.id, forKey: "lastTrackID")
        d.set(currentTime, forKey: "lastTrackTime")
    }

    /// Ricarica l'ultimo brano ascoltato, in pausa.
    func restoreLastSession(from library: [Track]) {
        guard current == nil, !library.isEmpty else { return }
        let d = UserDefaults.standard
        guard let id = d.string(forKey: "lastTrackID"),
              let idx = library.firstIndex(where: { $0.id == id }) else { return }
        queue = library
        rebuildOrder(startingAt: idx)
        load(index: idx, autoplay: false)
        let t = d.double(forKey: "lastTrackTime")
        if t > 1, t < duration - 1 { seek(to: t) }
    }
}

extension PlayerEngine: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.advance(auto: true)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Errore di decodifica del file"
            self?.advance(auto: true)
        }
    }
}
