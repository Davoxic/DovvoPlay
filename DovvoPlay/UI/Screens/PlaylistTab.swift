import SwiftUI

public struct PlaylistTab: View {
    @ObservedObject private var lib = LibraryService.shared
    @ObservedObject private var player = AudioPlayerService.shared

    @State private var showingCreateDialog: Bool = false
    @State private var newPlaylistName: String = ""

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header Card
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppTheme.primaryGradient)
                                    .frame(width: 52, height: 52)
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Le Tue Playlist")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("\(lib.playlists.count) \(lib.playlists.count == 1 ? "playlist creata" : "playlist create")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.secondary)
                            }

                            Spacer()

                            Button(action: {
                                newPlaylistName = ""
                                showingCreateDialog = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppTheme.surfaceCard)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.goldBorder, lineWidth: 1.2))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Playlists List
                        if lib.playlists.isEmpty {
                            VStack(spacing: 14) {
                                Spacer(minLength: 40)
                                Image(systemName: "rectangle.stack.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("Nessuna playlist creata")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Tocca il tasto + in alto per organizzare i tuoi brani in raccolte personalizzate.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                Spacer(minLength: 40)
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(lib.playlists) { pl in
                                    NavigationLink(destination: PlaylistDetailView(playlist: pl)) {
                                        playlistRow(pl: pl)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 120) // space for MiniPlayer
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Playlist")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        newPlaylistName = ""
                        showingCreateDialog = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .alert("Nuova Playlist", isPresented: $showingCreateDialog) {
                TextField("Nome playlist", text: $newPlaylistName)
                Button("Annulla", role: .cancel) {}
                Button("Crea") {
                    let trimmed = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        lib.createPlaylist(name: trimmed)
                    }
                }
            } message: {
                Text("Inserisci il nome della nuova playlist.")
            }
        }
    }

    private func playlistRow(pl: Playlist) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(pl.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                let count = pl.trackIds.count
                Text("\(count) \(count == 1 ? "brano" : "brani")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.secondary)
            }

            Spacer()

            if !pl.trackIds.isEmpty {
                Button(action: {
                    let tracks = lib.getTracksForPlaylist(pl)
                    if let first = tracks.first {
                        player.playTrack(first, newQueue: tracks)
                    }
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.primary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
        )
    }
}
