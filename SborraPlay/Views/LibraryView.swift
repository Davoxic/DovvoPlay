import SwiftUI

enum BrowseMode: String, CaseIterable, Identifiable {
    case songs = "Brani"
    case albums = "Album"
    case artists = "Artisti"
    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @State var mode: BrowseMode = .songs
    @State var query = ""
    @State var addingTo: Track?

    private var filteredTracks: [Track] { library.search(query) }

    private var filteredAlbums: [AlbumGroup] {
        guard !query.isEmpty else { return library.albums }
        let q = query.lowercased()
        return library.albums.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    private var filteredArtists: [ArtistGroup] {
        guard !query.isEmpty else { return library.artists }
        let q = query.lowercased()
        return library.artists.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if library.tracks.isEmpty && !library.isScanning {
                    EmptyLibraryView()
                } else {
                    content
                }
            }
            .navigationTitle("Libreria")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Cerca brani, album, artisti")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Ordina", selection: Binding(get: { library.sortMode },
                                                            set: { library.sortMode = $0 })) {
                            ForEach(SortMode.allCases) { Text($0.label).tag($0) }
                        }
                        Divider()
                        Button {
                            Task { await library.rescan(force: true) }
                        } label: {
                            Label("Rileggi i metadati", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("", selection: $mode) {
                    ForEach(BrowseMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .sheet(item: $addingTo) { track in
                AddToPlaylistSheet(track: track).environmentObject(library)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .songs: songsList
        case .albums: albumsGrid
        case .artists: artistsList
        }
    }

    private var songsList: some View {
        List {
            if library.isScanning {
                ScanRow()
            }
            Section {
                ForEach(filteredTracks) { track in
                    TrackRow(track: track)
                        .onTapGesture { player.play(track: track, in: filteredTracks) }
                        .contextMenu { TrackContextMenu(track: track, addingTo: $addingTo).environmentObject(library) }
                }
            } header: {
                PlayHeaderButtons(tracks: filteredTracks)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .refreshable { await library.rescan() }
    }

    private var albumsGrid: some View {
        ScrollView {
            if library.isScanning { ScanRow().padding() }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                ForEach(filteredAlbums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ArtworkView(artworkID: album.artworkID, size: 164, corner: 10, seed: album.id)
                                .frame(maxWidth: .infinity)
                            Text(album.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(album.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 90)
        }
    }

    private var artistsList: some View {
        List {
            ForEach(filteredArtists) { artist in
                NavigationLink {
                    ArtistDetailView(artist: artist)
                } label: {
                    HStack(spacing: 12) {
                        ArtworkView(artworkID: artist.artworkID, size: 46, corner: 23, seed: artist.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artist.name).lineLimit(1)
                            Text("\(artist.tracks.count) brani · \(artist.albumCount) album")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ScanRow: View {
    @EnvironmentObject var library: LibraryStore
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(library.scanTotal > 0
                 ? "Scansione \(library.scanDone)/\(library.scanTotal)…"
                 : "Scansione in corso…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct AlbumDetailView: View {
    let album: AlbumGroup
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @State var addingTo: Track?

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ArtworkView(artworkID: album.artworkID, size: 200, corner: 14, seed: album.id)
                    Text(album.title).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    Text(album.artist).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(album.tracks.count) brani · \(Track.timeString(album.totalDuration))")
                        .font(.caption).foregroundStyle(.secondary)
                    PlayHeaderButtons(tracks: album.tracks)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }
            Section {
                ForEach(Array(album.tracks.enumerated()), id: \.element.id) { idx, track in
                    TrackRow(track: track,
                             trailingNumber: track.trackNumber > 0 ? track.trackNumber : idx + 1)
                        .onTapGesture { player.play(track: track, in: album.tracks) }
                        .contextMenu { TrackContextMenu(track: track, addingTo: $addingTo).environmentObject(library) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $addingTo) { track in
            AddToPlaylistSheet(track: track).environmentObject(library)
        }
    }
}

struct ArtistDetailView: View {
    let artist: ArtistGroup
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @State var addingTo: Track?

    private var albums: [AlbumGroup] {
        var map: [String: [Track]] = [:]
        for t in artist.tracks { map[t.albumKey, default: []].append(t) }
        return map.map { key, value in
            let ordered = value.sorted {
                if $0.discNumber != $1.discNumber { return $0.discNumber < $1.discNumber }
                return $0.trackNumber < $1.trackNumber
            }
            return AlbumGroup(id: key,
                              title: ordered.first?.displayAlbum ?? "",
                              artist: ordered.first?.effectiveAlbumArtist ?? "",
                              tracks: ordered)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                PlayHeaderButtons(tracks: artist.tracks)
                    .listRowSeparator(.hidden)
            }
            ForEach(albums) { album in
                Section {
                    ForEach(album.tracks) { track in
                        TrackRow(track: track, showArtwork: false)
                            .onTapGesture { player.play(track: track, in: album.tracks) }
                            .contextMenu { TrackContextMenu(track: track, addingTo: $addingTo).environmentObject(library) }
                    }
                } header: {
                    HStack(spacing: 10) {
                        ArtworkView(artworkID: album.artworkID, size: 34, corner: 6, seed: album.id)
                        Text(album.title).font(.subheadline.weight(.medium))
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $addingTo) { track in
            AddToPlaylistSheet(track: track).environmentObject(library)
        }
    }
}
