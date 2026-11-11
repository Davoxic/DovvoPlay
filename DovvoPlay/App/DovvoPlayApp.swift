import SwiftUI
import AVFoundation

@main
struct DovvoPlayApp: App {
    @ObservedObject private var themeService = ThemeService.shared
    @ObservedObject private var lib = LibraryService.shared

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .preferredColorScheme(.dark)
                .accentColor(AppTheme.primary)
                .task {
                    // 1. Auto-restore backup if app was reinstalled or library empty
                    BackupService.shared.attemptAutoRestore()

                    // 2. Scan music documents
                    await lib.scanLibrary()

                    // 3. Check PC connectivity in background
                    await PcSyncService.shared.discoverPcOnLan()
                }
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("[DovvoPlayApp] Errore configurazione AVAudioSession: \(error)")
        }
    }
}
