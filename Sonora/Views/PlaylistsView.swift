import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var library: LibraryStore
    @State var showingNew = false
    @State var newName = ""
    @State var renaming: Playlist?
    @State var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if library.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Nessuna playlist").font(.title3.weight(.semibold))
                        Text("Creane una qui, importa un file .m3u dall'app File, oppure mandale dal PC con sonora-dl.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 60)
                } else {
                    List {
                        ForEach(library.playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlist: playlist)
                            } label: {
                                HStack(spacing: 12) {
                                    ArtworkView(artworkID: library.tracks(in: playlist).first?.artworkID,
                                                size: 46, seed: playlist.name)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name).lineLimit(1)
                                        Text(playlist.subtitle)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
                                    renaming = playlist
                                    renameText = playlist.name
                                } label: {
                                    Label("Rinomina", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    library.deletePlaylists(ids: [playlist.id])
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { library.playlists[$0].id }
                            library.deletePlaylists(ids: Set(ids))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Playlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newName = ""
                        showingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Nuova playlist", isPresented: $showingNew) {
                TextField("Nome", text: $newName)
                Button("Annulla", role: .cancel) {}
                Button("Crea") { library.createPlaylist(name: newName) }
            }
            .alert("Rinomina", isPresented: Binding(get: { renaming != nil },
                                                    set: { if !$0 { renaming = nil } })) {
                TextField("Nome", text: $renameText)
                Button("Annulla", role: .cancel) { renaming = nil }
                Button("Salva") {
                    if let p = renaming { library.rename(playlist: p, to: renameText) }
                    renaming = nil
                }
            }
        }
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @State var editMode: EditMode = .inactive
    @State var showPicker = false

    private var current: Playlist {
        library.playlists.first { $0.id == playlist.id } ?? playlist
    }
    private var tracks: [Track] { library.tracks(in: current) }

    var body: some View {
        List {
            Section {
                PlayHeaderButtons(tracks: tracks)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(tracks) { track in
                    TrackRow(track: track)
                        .onTapGesture { player.play(track: track, in: tracks) }
                }
                .onDelete { offsets in
                    library.removeTracks(at: offsets, from: current)
                }
                .onMove { source, destination in
                    library.moveTracks(from: source, to: destination, in: current)
                }
            } header: {
                Text(current.subtitle).textCase(nil)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(editMode == .active ? "Fine" : "Modifica") {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            TrackPickerSheet(playlist: current).environmentObject(library)
        }
    }
}

/// Selezione multipla di brani da aggiungere a una playlist.
struct TrackPickerSheet: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) var dismiss
    @State var selection = Set<String>()
    @State var query = ""

    private var results: [Track] { library.search(query) }

    var body: some View {
        NavigationStack {
            List(results) { track in
                HStack(spacing: 12) {
                    ArtworkView(artworkID: track.artworkID, size: 40, seed: track.albumKey)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle).lineLimit(1)
                        Text(track.displayArtist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: selection.contains(track.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(track.id) ? Color.accentColor : Color.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selection.contains(track.id) { selection.remove(track.id) }
                    else { selection.insert(track.id) }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Cerca")
            .navigationTitle("Aggiungi brani")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi (\(selection.count))") {
                        let ordered = results.filter { selection.contains($0.id) }.map { $0.id }
                        library.add(trackIDs: ordered, to: playlist)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}
