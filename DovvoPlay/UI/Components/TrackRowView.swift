import SwiftUI

public struct TrackRowView: View {
    public let track: Track
    public let queue: [Track]
    public let mode: LibraryViewMode
    public let index: Int
    public let onPlay: () -> Void

    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var lib = LibraryService.shared

    @State private var showingPlaylistSheet: Bool = false

    public init(
        track: Track,
        queue: [Track],
        mode: LibraryViewMode,
        index: Int = 0,
        onPlay: @escaping () -> Void
    ) {
        self.track = track
        self.queue = queue
        self.mode = mode
        self.index = index
        self.onPlay = onPlay
    }

    private var isCurrent: Bool {
        return player.currentTrack?.id == track.id
    }

    private var isPlaying: Bool {
        return isCurrent && player.isPlaying
    }

    public var body: some View {
        Group {
            switch mode {
            case .modernCards:
                modernCardsLayout
            case .compactList:
                compactListLayout
            case .gridCovers:
                gridCoversLayout
            case .gridCompact:
                gridCompactLayout
            case .cdJewelCase:
                cdJewelCaseLayout
            case .vinylCrate:
                vinylCrateLayout
            case .cassetteTape:
                cassetteTapeLayout
            case .minimalTypography:
                minimalTypographyLayout
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .contextMenu {
            Button(action: {
                player.playTrack(track, newQueue: queue)
            }) {
                Label("Riproduci ora", systemImage: "play.fill")
            }

            Button(action: {
                player.playNext(track)
            }) {
                Label("Riproduci dopo", systemImage: "text.insert")
            }

            Button(action: {
                player.addToQueue(track)
            }) {
                Label("Aggiungi in coda", systemImage: "text.append")
            }

            Menu("Aggiungi a playlist...") {
                ForEach(lib.playlists) { pl in
                    Button(pl.name) {
                        lib.addTrackToPlaylist(playlistId: pl.id, trackId: track.id)
                    }
                }
            }

            Divider()

            Button(role: .destructive, action: {
                lib.deleteTrack(track)
            }) {
                Label("Elimina brano", systemImage: "trash.fill")
            }
        }
    }

    // --- 1. MODERN CARDS ---
    private var modernCardsLayout: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                TrackArtworkView(urlString: track.thumbnailUrl, size: 52, cornerRadius: 10)
                if isCurrent {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                        )
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(.system(size: 15, weight: isCurrent ? .bold : .semibold))
                    .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if track.bpm != nil {
                Text("\(Int(track.bpm!)) BPM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.secondary.opacity(0.12))
                    .cornerRadius(6)
            }

            Text(track.formattedDuration)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isCurrent ? AppTheme.primary.opacity(0.08) : AppTheme.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCurrent ? AppTheme.primary : AppTheme.goldBorder, lineWidth: isCurrent ? 1.4 : 1.0)
                )
        )
    }

    // --- 2. COMPACT LIST ---
    private var compactListLayout: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textMuted)
                .frame(width: 24, alignment: .leading)

            TrackArtworkView(urlString: track.thumbnailUrl, size: 36, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.formattedDuration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isCurrent ? AppTheme.primary.opacity(0.1) : Color.clear
        )
    }

    // --- 3. GRID COVERS 2x2 ---
    private var gridCoversLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    TrackArtworkView(urlString: track.thumbnailUrl, size: geo.size.width, cornerRadius: 14)

                    if isCurrent {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                            )
                            .padding(8)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isCurrent ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1))
        )
    }

    // --- 4. GRID COMPACT 3x3 ---
    private var gridCompactLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                TrackArtworkView(urlString: track.thumbnailUrl, size: geo.size.width, cornerRadius: 8)
            }
            .aspectRatio(1, contentMode: .fit)

            Text(track.displayTitle)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isCurrent ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1))
        )
    }

    // --- 5. CD JEWEL CASE ---
    private var cdJewelCaseLayout: some View {
        HStack(spacing: 0) {
            // Jewel case clear spine
            Rectangle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 8)

            TrackArtworkView(urlString: track.thumbnailUrl, size: 56, cornerRadius: 0)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(track.displayTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondary)
                }

                Text(track.displayArtist)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)

                Text(track.formattedDuration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isCurrent ? AppTheme.primary : Color.white.opacity(0.2), lineWidth: 1.2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // --- 6. VINYL CRATE ---
    private var vinylCrateLayout: some View {
        HStack(spacing: 12) {
            ZStack {
                // Vinyl record sliding out
                Circle()
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .overlay(Circle().fill(AppTheme.primary).frame(width: 14, height: 14))
                    .offset(x: 14)

                TrackArtworkView(urlString: track.thumbnailUrl, size: 52, cornerRadius: 4)
            }
            .frame(width: 68)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.formattedDuration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1))
        )
    }

    // --- 7. CASSETTE TAPE ---
    private var cassetteTapeLayout: some View {
        VStack(spacing: 6) {
            HStack {
                Text("A面 · STEREO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppTheme.secondary)
                Spacer()
                Text(track.formattedDuration)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AppTheme.textMuted)
            }

            HStack(spacing: 10) {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 16, height: 16)
                Rectangle().fill(Color.black.opacity(0.4)).frame(height: 8).cornerRadius(2)
                Circle().fill(Color.white.opacity(0.2)).frame(width: 16, height: 16)
            }
            .padding(.horizontal, 10)

            HStack {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(track.displayArtist)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isCurrent ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1.2))
        )
    }

    // --- 8. MINIMAL TYPOGRAPHY ---
    private var minimalTypographyLayout: some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(isCurrent ? AppTheme.primary : AppTheme.textPrimary)
                    .lineLimit(1)

                Text(track.displayArtist.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.formattedDuration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isCurrent ? AppTheme.primary.opacity(0.08) : Color.clear
        )
    }
}
