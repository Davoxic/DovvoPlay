import SwiftUI

public struct MiniPlayerView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Binding public var isPresentingNowPlaying: Bool

    @State private var dragOffset: CGFloat = 0.0

    public init(isPresentingNowPlaying: Binding<Bool>) {
        self._isPresentingNowPlaying = isPresentingNowPlaying
    }

    public var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                // Progress Bar at very top of Mini Player
                GeometryReader { geo in
                    let pct = player.duration > 0 ? min(max(player.position / player.duration, 0.0), 1.0) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                        Rectangle()
                            .fill(AppTheme.primary)
                            .frame(width: geo.size.width * CGFloat(pct))
                    }
                }
                .frame(height: 2.5)

                HStack(spacing: 12) {
                    // Artwork
                    TrackArtworkView(urlString: track.thumbnailUrl, size: 44, cornerRadius: 8)

                    // Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)

                        Text(track.displayArtist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Play/Pause Button
                    Button(action: {
                        player.togglePlayPause()
                    }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 36, height: 36)
                    }

                    // Next Button
                    Button(action: {
                        player.next()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(player.hasNext || player.loopMode == .all ? AppTheme.textPrimary : AppTheme.textMuted)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.goldBorder, lineWidth: 1.2)
                    )
                    .shadow(color: AppTheme.primary.opacity(0.15), radius: 10, x: 0, y: 4)
            )
            .offset(x: dragOffset)
            .padding(.horizontal, 12)
            .padding(.bottom, 54) // right above tab bar
            .onTapGesture {
                isPresentingNowPlaying = true
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width

                        if translation < -60 || velocity < -200 {
                            // Swipe next
                            player.next()
                        } else if translation > 60 || velocity > 200 {
                            // Swipe previous
                            player.previous()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
            )
        }
    }
}
