import SwiftUI

struct SearchView: View {
    @EnvironmentObject var library: LibraryStore
    @StateObject var online = OnlineStore()
    @ObservedObject var player = PlayerEngine.shared

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
                .padding(.bottom, 8)

                if online.source == .youtube && !online.bridgeReady {
                    bridgeBanner
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
            .task { await online.refreshBridge() }
        }
    }

    private var prompt: String {
        online.source == .soundcloud ? "Cerca su SoundCloud" : "Cerca su YouTube"
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
                    .foregroundStyle(player.streamingItem?.id == track.id ? Color.accentColor : Color.primary)
                HStack(spacing: 5) {
                    Text(track.artist.isEmpty ? track.source.label : track.artist)
                        .lineLimit(1)
                    if track.duration > 0 {
                        Text("· \(track.durationText)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if online.isBusy(track) {
                ProgressView().frame(width: 30)
            } else {
                Button {
                    online.download(track, into: library)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 21))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { online.play(track) }
    }

    private var bridgeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("YouTube passa dal computer", systemImage: "desktopcomputer")
                .font(.footnote.weight(.medium))
            Text("yt-dlp non può girare su iPhone. Sul PC apri SborraPlay e scegli \"Avvia il ponte\": da quel momento cerchi e scarichi da YouTube anche da qui. SoundCloud invece funziona sempre, anche fuori casa.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Riprova il collegamento") {
                Task { await online.refreshBridge() }
            }
            .font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
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
            Text("Tocca un risultato per ascoltarlo subito, la freccia per salvarlo nella libreria.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 70)
    }
}
