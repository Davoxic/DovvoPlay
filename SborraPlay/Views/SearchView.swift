import SwiftUI

struct SearchView: View {
    @EnvironmentObject var library: LibraryStore
    @StateObject var online = OnlineStore()
    @ObservedObject var player = PlayerEngine.shared
    @ObservedObject var downloads = DownloadManager.shared
    @ObservedObject var network = NetworkMonitor.shared
    @State var playlistTarget: OnlineTrack?
    @State var pendingKind: DownloadKind = .audio(.auto)
    @ObservedObject var auth = SoundCloudAuth.shared
    @State var showLogin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $online.source) {
                    ForEach(OnlineSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 6)

                qualityBar

                if let message = player.errorMessage {
                    banner(message, symbol: "exclamationmark.triangle", tint: .orange)
                }

                content
            }
            .navigationTitle("Cerca online")
            .searchable(text: $online.query, prompt: prompt)
            .onSubmit(of: .search) { online.search() }
            .onChange(of: online.source) { _ in
                online.clear()
                if !online.query.isEmpty { online.search() }
            }
            .task { await online.refreshSources() }
            .sheet(isPresented: $showLogin) {
                SoundCloudLoginView()
            }
            .sheet(item: $playlistTarget) { track in
                OnlinePlaylistPicker(track: track) { playlist in
                    online.download(track, kind: pendingKind, into: library, addTo: playlist)
                }
                .environmentObject(library)
            }
        }
    }

    private var prompt: String {
        online.source == .soundcloud ? "Cerca su SoundCloud" : "Cerca su YouTube"
    }

    private var qualityBar: some View {
        HStack(spacing: 8) {
            Image(systemName: network.isWiFi ? "wifi" : "antenna.radiowaves.left.and.right")
                .font(.caption2)
            Text(online.connectionNote)
                .font(.caption2)
                .lineLimit(1)
            if online.source == .youtube && online.backend != "—" {
                Text("· via \(online.backend)").font(.caption2).lineLimit(1)
            }
            Spacer(minLength: 4)
            Menu {
                Picker("Qualità", selection: $online.quality) {
                    ForEach(StreamQuality.allCases) { q in
                        Label(q.label, systemImage: q.symbol).tag(q)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: online.quality.symbol)
                    Text("Qualità")
                }
                .font(.caption2.weight(.medium))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func banner(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.caption)
            Text(text).font(.caption)
            Spacer(minLength: 0)
            Button {
                player.clearError()
            } label: {
                Image(systemName: "xmark").font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(tint)
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if online.isSearching {
            VStack(spacing: 10) {
                ProgressView()
                Text("Sto cercando…").font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if online.results.isEmpty {
            placeholder
        } else {
            List {
                ForEach(online.results) { track in
                    row(for: track)
                }
                if let error = online.errorText {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(for track: OnlineTrack) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Color.secondary.opacity(0.15)
                    Image(systemName: track.source.symbol)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(titleColor(for: track))
                HStack(spacing: 5) {
                    Text(track.artist.isEmpty ? track.source.label : track.artist)
                        .lineLimit(1)
                    if track.duration > 0 { Text("· \(track.durationText)") }
                    if track.isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if track.isProtected {
                        Label("protetto", systemImage: "lock.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            trailing(for: track)
        }
        .contentShape(Rectangle())
        .onTapGesture { online.play(track, in: library) }
    }

    private func titleColor(for track: OnlineTrack) -> Color {
        if player.streamingItem?.id == track.id { return .accentColor }
        return track.isProtected ? .secondary : .primary
    }

    @ViewBuilder
    private func trailing(for track: OnlineTrack) -> some View {
        if let progress = online.progress(for: track) {
            ZStack {
                Circle()
                    .trim(from: 0, to: max(progress, 0.02))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
                Text("\(Int(progress * 100))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30)
        } else if online.isBusy(track) {
            ProgressView().frame(width: 30)
        } else if track.isProtected {
            Image(systemName: "lock.fill")
                .font(.system(size: 17))
                .foregroundStyle(.orange)
                .frame(width: 30)
        } else {
            Menu {
                Button {
                    online.play(track, in: library)
                } label: {
                    Label(track.isDownloaded ? "Ascolta il file" : "Ascolta in streaming",
                          systemImage: "play.fill")
                }

                Divider()

                if track.isDownloaded {
                    Button {
                        pendingKind = .audio(online.quality)
                        playlistTarget = track
                    } label: {
                        Label("Aggiungi a playlist…", systemImage: "text.badge.plus")
                    }
                } else if track.source == .youtube {
                    Button {
                        online.download(track, kind: .audio(.high), into: library)
                    } label: {
                        Label("Scarica in alta qualità", systemImage: "waveform")
                    }
                    Button {
                        online.download(track, kind: .audio(.saver), into: library)
                    } label: {
                        Label("Scarica leggero", systemImage: "arrow.down.circle.dotted")
                    }
                    Button {
                        pendingKind = .audio(online.quality)
                        playlistTarget = track
                    } label: {
                        Label("Scarica e aggiungi a…", systemImage: "text.badge.plus")
                    }
                    Divider()
                    Button {
                        online.download(track, kind: .video, into: library)
                    } label: {
                        Label("Scarica il video (mp4)", systemImage: "film")
                    }
                } else {
                    Button {
                        online.download(track, kind: .audio(online.quality), into: library)
                    } label: {
                        Label("Scarica", systemImage: "arrow.down")
                    }
                    Button {
                        pendingKind = .audio(online.quality)
                        playlistTarget = track
                    } label: {
                        Label("Scarica e aggiungi a…", systemImage: "text.badge.plus")
                    }
                }
            } label: {
                Image(systemName: track.isDownloaded ? "checkmark.circle.fill" : "ellipsis.circle")
                    .font(.system(size: 21))
                    .foregroundStyle(track.isDownloaded ? Color.green : Color.accentColor)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: online.source.symbol)
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(online.errorText ?? "Cerca un brano")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            if online.source == .soundcloud && !auth.isLoggedIn {
                VStack(spacing: 8) {
                    Text("Con il tuo account SoundCloud i brani che ora durano 30 secondi partono interi, e qui sotto trovi i tuoi preferiti.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showLogin = true
                    } label: {
                        Label("Accedi a SoundCloud", systemImage: "person.crop.circle")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 30)
                .padding(.top, 4)
            } else if online.source == .soundcloud && auth.isLoggedIn {
                Button {
                    online.loadLikes()
                } label: {
                    Label("Mostra i tuoi preferiti", systemImage: "heart")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
            } else if online.source == .youtube {
                Text(online.bridgeReady
                     ? "Il computer è collegato: le canzoni YouTube passano da lì."
                     : "YouTube oggi funziona solo col ponte acceso sul computer: sul PC apri SborraPlay e scegli \"Avvia il ponte\".")
                    .font(.caption)
                    .foregroundStyle(online.bridgeReady ? .green : .orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 70)
    }
}

/// Scelta della playlist in cui infilare il brano appena scaricato.
struct OnlinePlaylistPicker: View {
    let track: OnlineTrack
    var onPick: (Playlist) -> Void

    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) var dismiss
    @State var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        AsyncImage(url: track.artworkURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.15)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(.subheadline).lineLimit(1)
                            Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }

                Section("Nuova playlist") {
                    HStack {
                        TextField("Nome", text: $newName)
                        Button("Crea") {
                            let playlist = library.createPlaylist(name: newName)
                            onPick(playlist)
                            dismiss()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !library.playlists.isEmpty {
                    Section("Le tue playlist") {
                        ForEach(library.playlists) { playlist in
                            Button {
                                onPick(playlist)
                                dismiss()
                            } label: {
                                HStack {
                                    PlaylistCover(playlist: playlist,
                                                  fallbackArtworkID: library.tracks(in: playlist).first?.artworkID,
                                                  size: 34, corner: 6)
                                    Text(playlist.name)
                                    Spacer()
                                    Text(playlist.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Aggiungi a")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}
