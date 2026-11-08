import SwiftUI
import AVFoundation

@main
struct SonoraApp: App {
    @StateObject var library = LibraryStore()
    @Environment(\.scenePhase) var scenePhase

    init() {
        LibraryPaths.ensureDirectories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .tint(Color(red: 0.79, green: 0.42, blue: 1.0))
                .task { await startup() }
                .onOpenURL { url in
                    Task { await library.importFiles([url]) }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { LocalServer.shared.refreshAddresses() }
                }
        }
    }

    @MainActor
    private func startup() async {
        let store = library
        await store.bootstrap()
        PlayerEngine.shared.restoreLastSession(from: store.tracks)

        let server = LocalServer.shared
        server.onLibraryChanged = {
            Task { @MainActor in await store.rescan() }
        }
        server.onPlaylistReceived = { name, files in
            Task { @MainActor in
                await store.rescan()
                store.applyRemotePlaylist(name: name, fileNames: files)
            }
        }
        if UserDefaults.standard.bool(forKey: "serverAutoStart") {
            server.start()
        }
    }
}
