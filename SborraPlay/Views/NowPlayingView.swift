import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var player = PlayerEngine.shared
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) var dismiss
    @State var scrubbing = false
    @State var scrubValue: Double = 0
    @State var showQueue = false

    private var track: Track? { player.current }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: 38, height: 5)
                    .padding(.top, 10)

                Spacer(minLength: 10)

                LivePlayerArtwork(size: artSize, corner: 18)
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
                    .scaleEffect(player.isPlaying ? 1.0 : 0.94)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: player.isPlaying)

                Spacer(minLength: 16)

                VStack(spacing: 5) {
                    Text(player.hasTrack ? player.displayTitle : "Niente in riproduzione")
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(player.hasTrack ? player.displayArtist : "—")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    if !player.displaySubtitle.isEmpty {
                        HStack(spacing: 5) {
                            if player.isStreaming {
                                Image(systemName: "dot.radiowaves.left.and.right").font(.caption2)
                            }
                            Text(player.displaySubtitle)
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 28)

                progressSection
                    .padding(.top, 22)
                    .padding(.horizontal, 28)

                controls
                    .padding(.top, 6)

                secondaryControls
                    .padding(.top, 18)
                    .padding(.horizontal, 36)

                Spacer(minLength: 18)
            }
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showQueue) {
            QueueView().environmentObject(library)
        }
    }

    private var artSize: CGFloat {
        min(UIScreen.main.bounds.width - 90, 320)
    }

    private var background: some View {
        ZStack {
            if let img = player.artwork {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 60, opaque: true)
                    .overlay(Color.black.opacity(0.45))
            } else {
                LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.30),
                                        Color(red: 0.36, green: 0.14, blue: 0.42)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { scrubbing ? scrubValue : player.currentTime },
                set: { scrubValue = $0 }
            ), in: 0...max(player.duration, 1), onEditingChanged: { editing in
                if editing {
                    scrubbing = true
                    scrubValue = player.currentTime
                    player.beginScrub()
                } else {
                    scrubbing = false
                    player.endScrub(at: scrubValue)
                }
            })
            .tint(.white)

            HStack {
                Text(Track.timeString(scrubbing ? scrubValue : player.currentTime))
                Spacer()
                Text("-" + Track.timeString(max(player.duration - (scrubbing ? scrubValue : player.currentTime), 0)))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var controls: some View {
        HStack(spacing: 34) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.system(size: 28))
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
                    .symbolRenderingMode(.hierarchical)
            }
            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 28))
            }
        }
        .foregroundStyle(.white)
        .disabled(!player.hasTrack)
    }

    private var secondaryControls: some View {
        HStack {
            Button { player.shuffle.toggle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(player.shuffle ? Color.white : Color.white.opacity(0.45))
            }
            Spacer()
            Button { player.skip(by: -15) } label: {
                Image(systemName: "gobackward.15").font(.system(size: 19))
            }
            Spacer()
            Button { showQueue = true } label: {
                Image(systemName: "list.bullet").font(.system(size: 17, weight: .semibold))
            }
            Spacer()
            Button { player.skip(by: 15) } label: {
                Image(systemName: "goforward.15").font(.system(size: 19))
            }
            Spacer()
            Button { player.toggleRepeat() } label: {
                Image(systemName: player.repeatMode.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(player.repeatMode == .off ? Color.white.opacity(0.45) : Color.white)
            }
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

struct QueueView: View {
    @ObservedObject var player = PlayerEngine.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = player.current {
                    Section("In riproduzione") {
                        TrackRow(track: current)
                    }
                }
                let next = player.upNext
                if !next.isEmpty {
                    Section("A seguire") {
                        ForEach(Array(next.enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Coda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }
}

struct MiniPlayerView: View {
    @ObservedObject var player = PlayerEngine.shared
    var onTap: () -> Void

    var body: some View {
        if player.hasTrack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * player.progress)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    LivePlayerArtwork(size: 40, corner: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.displayTitle).font(.footnote.weight(.medium)).lineLimit(1)
                        HStack(spacing: 4) {
                            if player.isStreaming {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.accentColor)
                            }
                            Text(player.displayArtist)
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if player.isBuffering {
                        ProgressView().frame(width: 34, height: 34)
                    } else {
                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 19))
                                .frame(width: 34, height: 34)
                        }
                    }
                    if !player.isStreaming {
                        Button { player.next() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 17))
                                .frame(width: 34, height: 34)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .background(.ultraThinMaterial)
            .overlay(Divider(), alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}
