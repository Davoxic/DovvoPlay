import AVFoundation
import Foundation

// Carica davvero l'URL e dice se contiene audio riproducibile.
let args = CommandLine.arguments
guard args.count > 1, !args[1].isEmpty, let url = URL(string: args[1]) else {
    print("— nessun url da provare —")
    exit(0)
}
print("provo: \(args[1].prefix(100))")

let asset = AVURLAsset(url: url)
let item = AVPlayerItem(asset: asset)
let player = AVPlayer(playerItem: item)
player.volume = 0
player.play()

var esito = "TIMEOUT: non è mai partito"
let scadenza = Date().addingTimeInterval(25)
while Date() < scadenza {
    if item.status == .failed {
        esito = "FALLITO: \(item.error?.localizedDescription ?? "errore sconosciuto")"
        break
    }
    let t = CMTimeGetSeconds(player.currentTime())
    if t > 0.5 {
        esito = "RIPRODUCE: avanzato a \(String(format: "%.1f", t))s, durata \(String(format: "%.0f", CMTimeGetSeconds(item.duration)))s"
        break
    }
    Thread.sleep(forTimeInterval: 0.3)
}
print("   → \(esito)")
