import SwiftUI
import PhotosUI

/// Copertina di una playlist: foto scelta dal rullino, altrimenti l'artwork del
/// primo brano, altrimenti una tessera colorata.
struct PlaylistCover: View {
    let playlist: Playlist
    var fallbackArtworkID: String?
    var size: CGFloat = 160
    var corner: CGFloat = 10

    var body: some View {
        Group {
            if let image = CoverStore.image(for: playlist.coverID) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let art = ArtworkStore.image(for: fallbackArtworkID) {
                Image(uiImage: art).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note.list")
                        .font(.system(size: size * 0.3, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var colors: [Color] {
        let palette: [[Color]] = [
            [Color(red: 0.49, green: 0.25, blue: 0.75), Color(red: 0.85, green: 0.33, blue: 0.52)],
            [Color(red: 0.16, green: 0.38, blue: 0.70), Color(red: 0.36, green: 0.73, blue: 0.80)],
            [Color(red: 0.85, green: 0.45, blue: 0.20), Color(red: 0.76, green: 0.22, blue: 0.40)],
            [Color(red: 0.20, green: 0.55, blue: 0.40), Color(red: 0.52, green: 0.76, blue: 0.35)],
            [Color(red: 0.35, green: 0.30, blue: 0.62), Color(red: 0.62, green: 0.43, blue: 0.85)]
        ]
        return palette[abs(playlist.name.hashValue) % palette.count]
    }
}

struct PlaylistsView: View {
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared

    @State var showingNew = false
    @State var newName = ""
    @State var renaming: Playlist?
    @State var renameText = ""
    @State var coverTarget: Playlist?
    @State var showPicker = false
    @State var pickedItem: PhotosPickerItem?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if library.playlists.isEmpty {
                    empty
                } else {
                    grid
                }
            }
            .navigationTitle("Le tue playlist")
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
            .photosPicker(isPresented: $showPicker, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { item in
                guard let item, let target = coverTarget else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { library.setCover(data: data, for: target) }
                    }
                    await MainActor.run {
                        pickedItem = nil
                        coverTarget = nil
                    }
                }
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(library.playlists) { playlist in
                    let tracks = library.tracks(in: playlist)
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            PlaylistCover(playlist: playlist,
                                          fallbackArtworkID: tracks.first?.artworkID,
                                          size: 164)
                                .frame(maxWidth: .infinity)
                            Text(playlist.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Text(playlist.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            player.play(tracks: tracks, startAt: 0)
                        } label: {
                            Label("Riproduci", systemImage: "play.fill")
                        }
                        .disabled(tracks.isEmpty)
                        Button {
                            coverTarget = playlist
                            showPicker = true
                        } label: {
                            Label("Scegli copertina dalle foto", systemImage: "photo")
                        }
                        if playlist.coverID != nil {
                            Button {
                                library.removeCover(for: playlist)
                            } label: {
                                Label("Togli copertina", systemImage: "photo.badge.arrow.down")
                            }
                        }
                        Button {
                            renaming = playlist
                            renameText = playlist.name
                        } label: {
                            Label("Rinomina", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            library.deletePlaylists(ids: [playlist.id])
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Nessuna playlist").font(.title3.weight(.semibold))
            Text("Creane una col + qui sopra, importa un .m3u dall'app File, oppure mandale dal PC con sborraplay-dl.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @State var editMode: EditMode = .inactive
    @State var showPicker = false
    @State var showTrackPicker = false
    @State var pickedItem: PhotosPickerItem?

    private var current: Playlist {
        library.playlists.first { $0.id == playlist.id } ?? playlist
    }
    private var tracks: [Track] { library.tracks(in: current) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    PlaylistCover(playlist: current,
                                  fallbackArtworkID: tracks.first?.artworkID,
                                  size: 190, corner: 12)
                        .onTapGesture { showPicker = true }
                    Text(current.name)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(current.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showPicker = true
                    } label: {
                        Label(current.coverID == nil ? "Scegli copertina" : "Cambia copertina",
                              systemImage: "photo")
                            .font(.footnote)
                    }
                    PlayHeaderButtons(tracks: tracks)
                }
                .frame(maxWidth: .infinity)
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
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showTrackPicker = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(editMode == .active ? "Fine" : "Modifica") {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                }
            }
        }
        .sheet(isPresented: $showTrackPicker) {
            TrackPickerSheet(playlist: current).environmentObject(library)
        }
        .photosPicker(isPresented: $showPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { item in
            guard let item else { return }
            let target = current
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { library.setCover(data: data, for: target) }
                }
                await MainActor.run { pickedItem = nil }
            }
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
