import SwiftUI

public struct PlaylistDetailView: View {
    public let playlist: Playlist

    @ObservedObject private var lib = LibraryService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingAddTracksSheet: Bool = false
    @State private var showingRenameAlert: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var renamedTitle: String = ""

    public init(playlist: Playlist) {
        self.playlist = playlist
    }

    private var currentPlaylist: Playlist {
        return lib.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }

    private var tracksInPlaylist: [Track] {
        return lib.getTracksForPlaylist(currentPlaylist)
    }

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header Artwork & Stats
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(AppTheme.primaryGradient)
                                .frame(width: 140, height: 140)
                                .shadow(color: AppTheme.primary.opacity(0.35), radius: 18)
                            Image(systemName: "music.note.list")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(.black)
                        }

                        Text(currentPlaylist.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        let count = tracksInPlaylist.count
                        let totalSec = tracksInPlaylist.reduce(0) { $0 + Int($1.duration) }
                        Text("\(count) \(count == 1 ? "brano" : "brani") • \(formatTotalTime(totalSec))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.secondary)

                        // Action Buttons: Play All & Shuffle
                        if !tracksInPlaylist.isEmpty {
                            HStack(spacing: 12) {
                                Button(action: {
                                    if let first = tracksInPlaylist.first {
                                        player.playTrack(first, newQueue: tracksInPlaylist)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Riproduci")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(AppTheme.primary))
                                }

                                Button(action: {
                                    player.setShuffleMode(.standard, baseList: tracksInPlaylist)
                                    if let first = player.queue.first {
                                        player.playTrack(first)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "shuffle")
                                        Text("Shuffle")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(AppTheme.surfaceCard)
                                            .overlay(Capsule().stroke(AppTheme.goldBorder, lineWidth: 1))
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 10)

                    // Tracks List
                    if tracksInPlaylist.isEmpty {
                        VStack(spacing: 12) {
                            Spacer(minLength: 30)
                            Text("Playlist vuota")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Aggiungi brani dalla tua libreria toccando il pulsante qui sotto.")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                showingAddTracksSheet = true
                            }) {
                                Label("Aggiungi brani", systemImage: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(AppTheme.primary))
                            }
                            .padding(.top, 6)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(tracksInPlaylist.enumerated()), id: \.element.id) { index, track in
                                TrackRowView(track: track, queue: tracksInPlaylist, mode: .modernCards, index: index) {
                                    player.playTrack(track, newQueue: tracksInPlaylist)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120) // space for MiniPlayer
                    }
                }
            }
        }
        .navigationTitle(currentPlaylist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingAddTracksSheet = true
                    }) {
                        Label("Aggiungi brani", systemImage: "plus")
                    }

                    Button(action: {
                        renamedTitle = currentPlaylist.name
                        showingRenameAlert = true
                    }) {
                        Label("Rinomina playlist", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Elimina playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .alert("Rinomina Playlist", isPresented: $showingRenameAlert) {
            TextField("Nuovo nome", text: $renamedTitle)
            Button("Annulla", role: .cancel) {}
            Button("Salva") {
                let trimmed = renamedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lib.renamePlaylist(id: currentPlaylist.id, newName: trimmed)
                }
            }
        }
        .alert("Elimina Playlist", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                lib.deletePlaylist(id: currentPlaylist.id)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Vuoi davvero eliminare la playlist \"\(currentPlaylist.name)\"? I file musicali rimarranno salvati nella libreria.")
        }
        .sheet(isPresented: $showingAddTracksSheet) {
            AddTracksToPlaylistSheet(playlist: currentPlaylist)
        }
    }

    private func formatTotalTime(_ sec: Int) -> String {
        if sec < 60 { return "\(sec)s" }
        let mins = sec / 60
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        let remMins = mins % 60
        return "\(hours)h \(remMins)m"
    }
}

private struct AddTracksToPlaylistSheet: View {
    let playlist: Playlist
    @ObservedObject private var lib = LibraryService.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var searchText: String = ""

    private var availableTracks: [Track] {
        let all = lib.tracks
        if searchText.isEmpty {
            return all
        }
        let lower = searchText.lowercased()
        return all.filter { $0.title.lowercased().contains(lower) || $0.artist.lowercased().contains(lower) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack {
                    TextField("Cerca brani...", text: $searchText)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceCard))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    List(availableTracks) { track in
                        let alreadyIn = playlist.trackIds.contains(track.id)
                        HStack {
                            TrackArtworkView(urlString: track.thumbnailUrl, size: 42, cornerRadius: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.displayTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Text(track.displayArtist)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()

                            Button(action: {
                                if alreadyIn {
                                    lib.removeTrackFromPlaylist(playlistId: playlist.id, trackId: track.id)
                                } else {
                                    lib.addTrackToPlaylist(playlistId: playlist.id, trackId: track.id)
                                }
                            }) {
                                Image(systemName: alreadyIn ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(alreadyIn ? AppTheme.primary : AppTheme.textMuted)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(AppTheme.surfaceCard)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Aggiungi a \(playlist.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
}
