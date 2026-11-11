import SwiftUI

public struct YouTubeTabView: View {
    @ObservedObject private var ytService = YouTubeService.shared
    @ObservedObject private var sync = PcSyncService.shared
    @ObservedObject private var queue = DownloadQueueService.shared
    @ObservedObject private var lib = LibraryService.shared

    @State private var searchInput: String = ""
    @State private var results: [YouTubeTrack] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var toastMessage: String? = nil

    // Download modal state
    @State private var selectedTrackForDownload: YouTubeTrack? = nil
    @State private var showingDownloadChoice: Bool = false
    @State private var downloadingTrackIds: Set<String> = []
    @State private var downloadProgress: [String: Double] = [:]

    private let quickSearches = [
        "Top Italia 2026",
        "Rap Italiano",
        "Lo-Fi Chill",
        "Pop Hits",
        "Synthwave",
        "Rock Classico"
    ]

    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Info Banner
                infoBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Search Bar
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Quick Search Tags
                quickSearchTags
                    .padding(.bottom, 10)

                Divider()
                    .background(AppTheme.goldBorder)

                // Content / Results
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                        .scaleEffect(1.4)
                    Text("Ricerca in corso...")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 12)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.primary.opacity(0.4))
                        Text("Cerca milioni di tracce su YouTube")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Streaming audio istantaneo senza video o scarica offline nella libreria.")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    resultsList
                }
            }

            // Toast overlay
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.black)
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .cornerRadius(24)
                    .shadow(radius: 8)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .navigationTitle("YouTube Music Online")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Dove scarico \"\(selectedTrackForDownload?.title ?? "")\"?",
            isPresented: $showingDownloadChoice,
            titleVisibility: .visible
        ) {
            Button("Sul telefono (Download Locale)") {
                if let track = selectedTrackForDownload {
                    downloadLocally(track)
                }
            }
            Button("Delega al PC (tramite yt-dlp)") {
                if let track = selectedTrackForDownload {
                    queue.enqueue(
                        url: "https://www.youtube.com/watch?v=\(track.id)",
                        label: track.title,
                        kind: .singolo
                    )
                    showToast("\"\(track.title)\" accodato sul PC!")
                }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Il telefono scarica subito via stream audio; il PC usa yt-dlp per la massima stabilità.")
        }
    }

    private func showToast(_ text: String) {
        withAnimation {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                if toastMessage == text {
                    toastMessage = nil
                }
            }
        }
    }

    // MARK: - Info Banner
    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 22))
                .foregroundColor(AppTheme.primary)

            Text("Riproduzione solo audio AAC: streaming istantaneo e ascolto a schermo spento con controlli da Lock Screen.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.goldSurfaceGradient)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1.1))
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.primary)

            TextField("Cerca brano o artista su YouTube...", text: $searchInput)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onSubmit {
                    performSearch(searchInput)
                }

            if !searchInput.isEmpty {
                Button(action: {
                    searchInput = ""
                    results = []
                    errorMessage = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            Button(action: {
                performSearch(searchInput)
            }) {
                Text("Cerca")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.primary)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
        }
        .padding(10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - Quick Search Tags
    private var quickSearchTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickSearches, id: \.self) { tag in
                    Button(action: {
                        searchInput = tag
                        performSearch(tag)
                    }) {
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.surfaceLight)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(results) { track in
                    youTubeRow(track)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 90)
        }
    }

    private func youTubeRow(_ yt: YouTubeTrack) -> some View {
        let isDownloading = downloadingTrackIds.contains(yt.id)
        let prog = downloadProgress[yt.id] ?? 0.0

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Artwork thumbnail
                TrackArtworkView(artworkPath: yt.thumbnailUrl, title: yt.title, size: 54, cornerRadius: 8)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(yt.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(yt.author)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)

                        if !yt.formattedDuration.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                            Text(yt.formattedDuration)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }

                Spacer()

                // Actions: Stream / Play
                Button(action: {
                    playTrack(yt)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(AppTheme.primary)
                }

                // Download Button
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                        .scaleEffect(0.9)
                        .frame(width: 30, height: 30)
                } else {
                    Button(action: {
                        if sync.isConnected {
                            selectedTrackForDownload = yt
                            showingDownloadChoice = true
                        } else {
                            downloadLocally(yt)
                        }
                    }) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            // Progress bar if downloading
            if isDownloading {
                VStack(spacing: 3) {
                    ProgressView(value: prog)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primary))
                    HStack {
                        Text("Scaricamento audio offline...")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        Spacer()
                        Text("\(Int(prog * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.primary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 1))
    }

    private func performSearch(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let list = try await ytService.search(q)
                await MainActor.run {
                    self.results = list
                    self.isLoading = false
                    if list.isEmpty {
                        self.errorMessage = "Nessun risultato trovato per \"\(q)\". Prova con altre parole chiave."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Errore di connessione a YouTube (\(error.localizedDescription)).\nVerifica la connessione internet."
                }
            }
        }
    }

    private func playTrack(_ yt: YouTubeTrack) {
        Task {
            showToast("Caricamento stream audio: \(yt.title)")
            let audioStream = await ytService.extractAudioStream(yt.id)
            guard let stream = audioStream else {
                showToast("Impossibile estrarre lo stream audio.")
                return
            }

            let track = Track(
                id: "yt_\(yt.id)",
                title: yt.title,
                artist: yt.author,
                album: "YouTube Music",
                path: stream.url,
                duration: yt.durationSeconds,
                artworkPath: yt.thumbnailUrl,
                dateAdded: Date()
            )

            await MainActor.run {
                AudioPlayerService.shared.play(track: track, from: [track])
            }
        }
    }

    private func downloadLocally(_ yt: YouTubeTrack) {
        downloadingTrackIds.insert(yt.id)
        downloadProgress[yt.id] = 0.0

        Task {
            let file = await ytService.downloadAudioStream(yt.id, yt.title) { p in
                DispatchQueue.main.async {
                    self.downloadProgress[yt.id] = p
                }
            }

            await MainActor.run {
                downloadingTrackIds.remove(yt.id)
                downloadProgress.removeValue(forKey: yt.id)

                if file != nil {
                    Task {
                        await lib.scanLibrary()
                    }
                    showToast("Scaricato nella libreria: \(yt.title)")
                } else {
                    let reason = ytService.lastFailureReason ?? "Errore durante il download."
                    showToast(reason)
                }
            }
        }
    }
}
