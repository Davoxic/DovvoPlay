import SwiftUI

struct SearchView: View {
    @EnvironmentObject var library: LibraryStore
    @StateObject var online = OnlineStore()
    @ObservedObject var player = PlayerEngine.shared
    @ObservedObject var downloads = DownloadManager.shared
    @ObservedObject var network = NetworkMonitor.shared

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
            .task { await online.refreshBridge() }
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
                    .foregroundStyle(player.streamingItem?.id == track.id ? Color.accentColor : Color.primary)
                HStack(spacing: 5) {
                    Text(track.artist.isEmpty ? track.source.label : track.artist)
                        .lineLimit(1)
                    if track.duration > 0 { Text("· \(track.durationText)") }
                    if track.isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
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
        } else if track.isDownloaded {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 21))
                .foregroundStyle(.green)
        } else if track.source == .youtube {
            Menu {
                Button {
                    online.download(track, kind: .audio(.high), into: library)
                } label: {
                    Label("Alta qualità", systemImage: "waveform")
                }
                Button {
                    online.download(track, kind: .audio(.saver), into: library)
                } label: {
                    Label("Risparmio dati", systemImage: "arrow.down.circle.dotted")
                }
                Divider()
                Button {
                    online.download(track, kind: .video, into: library)
                } label: {
                    Label("Scarica il video (mp4)", systemImage: "film")
                }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 21))
                    .foregroundStyle(Color.accentColor)
            }
        } else {
            Button {
                online.download(track, kind: .audio(online.quality), into: library)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 21))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
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
            Text(online.source == .youtube
                 ? "YouTube passa dalle istanze Piped: niente PC acceso, niente configurazione."
                 : "Tocca un risultato per ascoltarlo, la freccia per salvarlo in libreria.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 70)
    }
}
