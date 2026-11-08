import SwiftUI

struct RootView: View {
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @State var selection = 0
    @State var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                LibraryView()
                    .tabItem { Label("Libreria", systemImage: "music.note.list") }
                    .tag(0)
                PlaylistsView()
                    .tabItem { Label("Playlist", systemImage: "rectangle.stack") }
                    .tag(1)
                SettingsView()
                    .tabItem { Label("Impostazioni", systemImage: "gearshape") }
                    .tag(2)
            }

            if player.hasTrack {
                MiniPlayerView { showNowPlaying = true }
                    .padding(.bottom, 49)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: player.hasTrack)
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView().environmentObject(library)
        }
        .overlay(alignment: .top) {
            if let message = library.lastMessage {
                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 6, y: 3)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run { withAnimation { library.lastMessage = nil } }
                    }
            }
        }
        .animation(.easeInOut, value: library.lastMessage)
    }
}
