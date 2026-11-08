import SwiftUI

/// Copertina con fallback grafico quando il brano non ha artwork.
struct ArtworkView: View {
    let artworkID: String?
    var size: CGFloat = 48
    var corner: CGFloat = 8
    var seed: String = ""

    var body: some View {
        Group {
            if let image = ArtworkStore.image(for: artworkID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: placeholderColors,
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.38, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var placeholderColors: [Color] {
        let palette: [[Color]] = [
            [Color(red: 0.49, green: 0.25, blue: 0.75), Color(red: 0.85, green: 0.33, blue: 0.52)],
            [Color(red: 0.16, green: 0.38, blue: 0.70), Color(red: 0.36, green: 0.73, blue: 0.80)],
            [Color(red: 0.85, green: 0.45, blue: 0.20), Color(red: 0.76, green: 0.22, blue: 0.40)],
            [Color(red: 0.20, green: 0.55, blue: 0.40), Color(red: 0.52, green: 0.76, blue: 0.35)],
            [Color(red: 0.35, green: 0.30, blue: 0.62), Color(red: 0.62, green: 0.43, blue: 0.85)]
        ]
        let key = seed.isEmpty ? (artworkID ?? "x") : seed
        let idx = abs(key.hashValue) % palette.count
        return palette[idx]
    }
}

/// Riga standard di un brano.
struct TrackRow: View {
    let track: Track
    var showArtwork = true
    var trailingNumber: Int? = nil
    @ObservedObject var player = PlayerEngine.shared

    private var isCurrent: Bool { player.current?.id == track.id }

    var body: some View {
        HStack(spacing: 12) {
            if let n = trailingNumber {
                Text("\(n)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            } else if showArtwork {
                ArtworkView(artworkID: track.artworkID, size: 46, seed: track.albumKey)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(.body)
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    .lineLimit(1)
                Text("\(track.displayArtist) · \(track.displayAlbum)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if isCurrent && player.isPlaying {
                Image(systemName: "waveform")
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Text(track.durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Pulsanti "Riproduci" / "Casuale" in testa a una lista.
struct PlayHeaderButtons: View {
    let tracks: [Track]
    @ObservedObject var player = PlayerEngine.shared

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.shuffle = false
                player.play(tracks: tracks, startAt: 0)
            } label: {
                Label("Riproduci", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            Button {
                player.playShuffled(tracks: tracks)
            } label: {
                Label("Casuale", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .disabled(tracks.isEmpty)
        .padding(.vertical, 4)
    }
}

/// Menu contestuale condiviso dalle righe dei brani.
struct TrackContextMenu: View {
    let track: Track
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var player = PlayerEngine.shared
    @Binding var addingTo: Track?

    var body: some View {
        Button {
            player.playNext([track])
        } label: {
            Label("Riproduci dopo", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        Button {
            player.appendToQueue([track])
        } label: {
            Label("Aggiungi in coda", systemImage: "text.append")
        }
        Button {
            addingTo = track
        } label: {
            Label("Aggiungi a playlist…", systemImage: "plus.rectangle.on.folder")
        }
        Divider()
        Button(role: .destructive) {
            Task { await library.delete(tracks: [track]) }
        } label: {
            Label("Elimina dal telefono", systemImage: "trash")
        }
    }
}

/// Foglio per scegliere in quale playlist mettere un brano.
struct AddToPlaylistSheet: View {
    let track: Track
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) var dismiss
    @State var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Nuova playlist") {
                    HStack {
                        TextField("Nome", text: $newName)
                        Button("Crea") {
                            let p = library.createPlaylist(name: newName, trackIDs: [track.id])
                            _ = p
                            dismiss()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if !library.playlists.isEmpty {
                    Section("Playlist esistenti") {
                        ForEach(library.playlists) { p in
                            Button {
                                library.add(trackIDs: [track.id], to: p)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(p.name)
                                    Spacer()
                                    Text(p.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Aggiungi a playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.house")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Nessun brano")
                .font(.title3.weight(.semibold))
            Text("Accendi il server Wi-Fi in Impostazioni e trascina i file dal computer, oppure importali dall'app File.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}
