import AVFoundation
import Foundation

// Su un tool a riga di comando AVFoundation ha bisogno del run loop:
// senza, il player non avanza mai e il test mente.
let args = CommandLine.arguments
guard args.count > 1, !args[1].isEmpty, let url = URL(string: args[1]) else {
    print("— nessun url —"); exit(0)
}
print("carico: \(args[1].prefix(90))")

let asset = AVURLAsset(url: url)
var esito = "TIMEOUT"
let fine = DispatchSemaphore(value: 0)

Task {
    do {
        let playable = try await asset.load(.isPlayable)
        let tracce = try await asset.loadTracks(withMediaType: .audio)
        let durata = CMTimeGetSeconds(try await asset.load(.duration))
        esito = "isPlayable=\(playable) tracceAudio=\(tracce.count) durata=\(String(format: "%.0f", durata))s"
        if !tracce.isEmpty {
            let formati = try await tracce[0].load(.formatDescriptions)
            esito += " formati=\(formati.count)"
        }
    } catch {
        esito = "ERRORE: \(error.localizedDescription)"
    }
    fine.signal()
}

let scadenza = Date().addingTimeInterval(40)
while fine.wait(timeout: .now() + 0.2) == .timedOut, Date() < scadenza {
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
print("   → \(esito)")
