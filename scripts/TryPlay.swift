import AVFoundation
import Foundation

// Prova davvero a caricare un URL con AVPlayer e dice se è riproducibile.
let args = CommandLine.arguments
guard args.count > 1, let url = URL(string: args[1]), !args[1].isEmpty else {
    print("nessun url da provare")
    exit(0)
}
print("provo: \(args[1].prefix(110))")

let asset = AVURLAsset(url: url)
let semaphore = DispatchSemaphore(value: 0)

asset.loadValuesAsynchronously(forKeys: ["playable", "tracks", "duration"]) {
    var error: NSError?
    let status = asset.statusOfValue(forKey: "playable", error: &error)
    print("statusOfValue(playable): \(status.rawValue)")
    if let error {
        print("ERRORE: \(error.domain) \(error.code) — \(error.localizedDescription)")
    }
    print("isPlayable: \(asset.isPlayable)")
    print("tracce audio: \(asset.tracks(withMediaType: .audio).count)")
    print("durata: \(CMTimeGetSeconds(asset.duration))")
    semaphore.signal()
}

if semaphore.wait(timeout: .now() + 45) == .timedOut {
    print("TIMEOUT: l'asset non si è caricato in 45 secondi")
}
