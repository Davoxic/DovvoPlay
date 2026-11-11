import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var isSeeking: Bool = false
    @State private var seekPosition: TimeInterval = 0.0
    @State private var ambientGlow: Bool = false
    @State private var isPulsing: Bool = false
    @State private var showingEqualizer: Bool = false
    @State private var showingQueue: Bool = false
    @State private var showingAnimationPicker: Bool = false
    @State private var showingShufflePicker: Bool = false

    public init() {}

    private var currentPosition: TimeInterval {
        return isSeeking ? seekPosition : player.position
    }

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Source Badge
                    if let track = player.currentTrack {
                        Text(track.isOnline ? "YOUTUBE MUSIC" : "LOCAL AUDIO")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.primary.opacity(0.15))
                            .cornerRadius(12)
                    }

                    Spacer()

                    Button(action: {
                        showingEqualizer = true
                    }) {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 12)

                // Large Artwork with Ambient Glow and Transition
                if let track = player.currentTrack {
                    GeometryReader { geo in
                        let size = min(geo.size.width - 48, geo.size.height - 20)
                        ZStack {
                            // Ambient BPM Pulsing Glow
                            if ambientGlow {
                                Circle()
                                    .fill(AppTheme.primary.opacity(isPulsing ? 0.35 : 0.12))
                                    .frame(width: size * 1.15, height: size * 1.15)
                                    .blur(radius: 40)
                            }

                            AnimatedTrackTransitionView(trackId: track.id) {
                                TrackArtworkView(
                                    urlString: track.thumbnailUrl,
                                    size: size,
                                    cornerRadius: 22
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(AppTheme.goldBorder, lineWidth: 1.5)
                                )
                                .shadow(color: AppTheme.primary.opacity(0.25), radius: 24, x: 0, y: 12)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            ambientGlow.toggle()
                            if ambientGlow {
                                startBpmPulse(bpm: track.bpm)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }

                Spacer(minLength: 16)

                // Track Title & Artist
                if let track = player.currentTrack {
                    VStack(spacing: 4) {
                        Text(track.displayTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)

                        Text(track.displayArtist)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.secondary)
                            .lineLimit(1)

                        if !track.album.isEmpty {
                            Text(track.album)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 28)
                }

                // Scrubber Slider
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { currentPosition },
                            set: {
                                isSeeking = true
                                seekPosition = $0
                            }
                        ),
                        in: 0...max(player.duration, 1.0),
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(to: seekPosition)
                                isSeeking = false
                            }
                        }
                    )
                    .tint(AppTheme.primary)

                    HStack {
                        Text(formatTime(currentPosition))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)

                        Spacer()

                        Text("-" + formatTime(max(player.duration - currentPosition, 0)))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)

                // Main Controls (Shuffle, Previous, Play/Pause, Next, Loop)
                HStack(spacing: 24) {
                    // Shuffle Mode
                    Button(action: {
                        player.cycleShuffleMode()
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: player.shuffleMode.systemImage)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(player.isShuffle ? AppTheme.primary : AppTheme.textMuted)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .onLongPressGesture {
                        showingShufflePicker = true
                    }

                    // Previous
                    Button(action: {
                        player.previous()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(player.hasPrevious ? AppTheme.textPrimary : AppTheme.textMuted)
                            .frame(width: 48, height: 48)
                    }

                    // Play/Pause Big Button
                    Button(action: {
                        player.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary)
                                .frame(width: 68, height: 68)
                                .shadow(color: AppTheme.primary.opacity(0.4), radius: 14)

                            if player.isBuffering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.black)
                                    .offset(x: player.isPlaying ? 0 : 2)
                            }
                        }
                    }

                    // Next
                    Button(action: {
                        player.next()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(player.hasNext || player.loopMode == .all ? AppTheme.textPrimary : AppTheme.textMuted)
                            .frame(width: 48, height: 48)
                    }

                    // Loop Mode
                    Button(action: {
                        player.toggleLoopMode()
                    }) {
                        ZStack {
                            Image(systemName: player.loopMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(player.loopMode != .off ? AppTheme.primary : AppTheme.textMuted)
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.top, 16)

                Spacer(minLength: 12)

                // Bottom Utilities Bar
                HStack(spacing: 32) {
                    Button(action: {
                        showingAnimationPicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: AnimationThemeService.shared.currentTheme.systemImage)
                            Text(AnimationThemeService.shared.currentTheme.name)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder, lineWidth: 1))
                    }

                    Button(action: {
                        showingQueue = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                            Text("Coda (\(player.queue.count))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(AppTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.primary.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder, lineWidth: 1))
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingEqualizer) {
            EqualizerSheetView()
        }
        .sheet(isPresented: $showingQueue) {
            QueueSheetView()
        }
        .sheet(isPresented: $showingAnimationPicker) {
            AnimationPickerSheetView()
        }
        .sheet(isPresented: $showingShufflePicker) {
            ShuffleModePickerSheetView()
        }
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let s = Int(sec.rounded())
        if s <= 0 { return "0:00" }
        let mins = s / 60
        let rem = s % 60
        return String(format: "%d:%02d", mins, rem)
    }

    private func startBpmPulse(bpm: Double?) {
        let period = (bpm != nil && bpm! >= 40 && bpm! <= 220) ? (60.0 / bpm!) : 1.2
        withAnimation(Animation.easeInOut(duration: period / 2.0).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

private struct QueueSheetView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                        let isCur = index == player.currentIndex
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(isCur ? AppTheme.primary : AppTheme.textMuted)
                                .frame(width: 22)

                            TrackArtworkView(urlString: track.thumbnailUrl, size: 40, cornerRadius: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.displayTitle)
                                    .font(.system(size: 14, weight: isCur ? .bold : .medium))
                                    .foregroundColor(isCur ? AppTheme.primary : AppTheme.textPrimary)
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
                        .padding(.vertical, 4)
                        .listRowBackground(isCur ? AppTheme.primary.opacity(0.1) : AppTheme.surfaceCard)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.playTrack(track)
                        }
                    }
                    .onDelete { indices in
                        for i in indices {
                            if i < player.queue.count {
                                player.removeFromQueue(trackId: player.queue[i].id)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Coda di Riproduzione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
}

private struct AnimationPickerSheetView: View {
    @ObservedObject private var animService = AnimationThemeService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List(AnimationThemeService.animations) { a in
                    let isSelected = animService.selectedType == a.type
                    HStack(spacing: 14) {
                        Image(systemName: a.systemImage)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textPrimary)
                            Text(a.description)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceCard)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        animService.setAnimationType(a.type)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Animazione Brani")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ShuffleModePickerSheetView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List(ShuffleMode.allCases) { mode in
                    let isSelected = player.shuffleMode == mode
                    HStack(spacing: 14) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.label)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textPrimary)
                            Text(mode.modeDescription)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceCard)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        player.setShuffleMode(mode)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Modalità Shuffle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
