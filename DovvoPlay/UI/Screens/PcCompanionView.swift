import SwiftUI

public struct PcCompanionView: View {
    @ObservedObject private var sync = PcSyncService.shared
    @ObservedObject private var queue = DownloadQueueService.shared
    @ObservedObject private var wifi = WifiServerService.shared

    @State private var hostInput: String = ""
    @State private var portInput: String = ""
    @State private var playlistUrlInput: String = ""
    @State private var delegateToPc: Bool = true
    @State private var isProcessingPlaylist: Bool = false
    @State private var playlistStatusText: String = ""

    // Multi-source Search Hub
    @State private var selectedSearchTab: Int = 0 // 0: YouTube, 1: Spotify, 2: SoundCloud
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var youtubeResults: [YouTubeTrack] = []
    @State private var spotifyResults: [SpotifyItem] = []
    @State private var soundCloudResults: [SoundCloudTrack] = []
    @State private var searchError: String? = nil

    // Alerts & Toasts
    @State private var showingPlaylistChoiceAlert: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isSpinning: Bool = false

    public init() {}

    private var isWorking: Bool {
        return sync.isSyncing || queue.isWorking
    }

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // 1. STATO CONNESSIONE PC
                    pcStatusCard

                    // 2. CONVERTITORE PLAYLIST SPOTIFY / URL
                    spotifyConverterCard

                    // 3. AVANZAMENTO SINCRONIZZAZIONE (se attivo)
                    if let progress = sync.syncProgress {
                        syncProgressCard(progress)
                    }

                    // 4. CODA DOWNLOAD DEL PC (se presenti job)
                    if !queue.jobs.isEmpty {
                        downloadQueueCard
                    }

                    // 5. TRASFERIMENTO WI-FI CARD
                    wifiQuickCard

                    // 6. CENTRO RICERCA MULTI-PIATTAFORMA
                    searchHubCard

                    // RISULTATI RICERCA
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                            .scaleEffect(1.3)
                            .padding(.vertical, 30)
                    } else if let error = searchError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        searchResultsList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 90)
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
                    .background(Color(hex: 0x4ADE80))
                    .cornerRadius(24)
                    .shadow(radius: 8)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .navigationTitle("PC Companion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if isWorking {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .rotationEffect(.degrees(isSpinning ? 360 : 0))
                            .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: isSpinning)
                            .onAppear { isSpinning = true }
                    }

                    Button(action: {
                        Task {
                            await sync.discoverPcOnLan()
                            if sync.isConnected {
                                showToast("PC trovato e collegato!")
                            } else {
                                showToast("Nessun PC trovato su rete locale")
                            }
                        }
                    }) {
                        Image(systemName: "wifi.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
        }
        .onAppear {
            hostInput = sync.pcHost
            portInput = "\(sync.pcPort)"
            checkForArrivedTracks()
            Task {
                await sync.fetchSyncProgress()
            }
        }
        .onChange(of: sync.arrivedTracks) { _ in
            checkForArrivedTracks()
        }
        .alert(isPresented: $showingPlaylistChoiceAlert) {
            Alert(
                title: Text("Cosa faccio con questa playlist?"),
                message: Text("Posso scaricare soltanto i brani oppure scaricarli e creare una playlist con lo stesso nome."),
                primaryButton: .default(Text("Brani + playlist")) {
                    processPlaylistUrl(createPlaylist: true)
                },
                secondaryButton: .default(Text("Solo i brani")) {
                    processPlaylistUrl(createPlaylist: false)
                }
            )
        }
    }

    private func checkForArrivedTracks() {
        if sync.hasArrivedTracks {
            let titles = sync.consumeArrivedTracks()
            if let first = titles.first {
                let msg = titles.count == 1 ? "Ricevuto dal PC: \(first)" : "Ricevuti dal PC \(titles.count) brani"
                showToast(msg)
            }
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

    // MARK: - 1. PC Status Card
    private var pcStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(sync.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(sync.isConnected ? "PC COLLEGATO" : "PC NON COLLEGATO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(sync.isConnected ? Color.green : AppTheme.textMuted)
                }
                Spacer()
                if sync.isDiscovering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                        .scaleEffect(0.8)
                }
            }

            HStack(spacing: 10) {
                // Host IP
                VStack(alignment: .leading, spacing: 4) {
                    Text("INDIRIZZO IP PC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                    TextField("192.168.1.xxx", text: $hostInput)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.goldBorder, lineWidth: 1))
                        .foregroundColor(AppTheme.textPrimary)
                }

                // Port
                VStack(alignment: .leading, spacing: 4) {
                    Text("PORTA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                    TextField("45678", text: $portInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 80)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.goldBorder, lineWidth: 1))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    let port = Int(portInput) ?? 45678
                    sync.connect(host: hostInput.trimmingCharacters(in: .whitespacesAndNewlines), port: port)
                    Task {
                        let ok = await sync.checkHealth()
                        if ok {
                            showToast("Connesso al PC con successo!")
                        } else {
                            showToast("Impossibile raggiungere il PC. Verifica IP e porta.")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text(sync.isConnected ? "Riconnetti" : "Connetti al PC")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }

                if sync.isConnected {
                    Button(action: {
                        sync.disconnect()
                        showToast("Disconnesso dal PC")
                    }) {
                        Text("Disconnetti")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.surfaceCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - 2. Spotify / URL Converter Card
    private var spotifyConverterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(AppTheme.primary)
                Text("CONVERTI LINK SPOTIFY & PLAYLIST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(AppTheme.primary.opacity(0.7))
            }

            Text("Incolla un link Spotify (canzone, album o playlist): l'app troverà l'audio ad alta qualità e scaricherà i brani.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("https://open.spotify.com/...", text: $playlistUrlInput)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textPrimary)

                if !playlistUrlInput.isEmpty {
                    Button(action: { playlistUrlInput = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Button(action: {
                    if let clip = UIPasteboard.general.string {
                        playlistUrlInput = clip
                    }
                }) {
                    Text("Incolla")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.surfaceLight)
                        .foregroundColor(AppTheme.primary)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder, lineWidth: 1))

            Toggle(isOn: $delegateToPc) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delega download e conversione al PC")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Usa la potenza e la stabilità di yt-dlp sul tuo computer")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .tint(AppTheme.primary)

            if isProcessingPlaylist {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primary))
                    Text(playlistStatusText.isEmpty ? "Elaborazione in corso..." : playlistStatusText)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 4)
            }

            Button(action: {
                handleImportButtonTapped()
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Scarica e Converti Ora")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.primaryGradient)
                .foregroundColor(.black)
                .cornerRadius(14)
            }
            .disabled(playlistUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessingPlaylist)
        }
        .padding(16)
        .background(AppTheme.surfaceCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    private func handleImportButtonTapped() {
        let url = playlistUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        if PcSyncService.isSingleTrackUrl(url) {
            processPlaylistUrl(createPlaylist: false)
        } else {
            showingPlaylistChoiceAlert = true
        }
    }

    private func processPlaylistUrl(createPlaylist: Bool) {
        let url = playlistUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        let isSingle = PcSyncService.isSingleTrackUrl(url)

        if delegateToPc {
            queue.enqueue(
                url: url,
                label: isSingle ? "Brano singolo" : "Playlist o album",
                kind: isSingle ? .singolo : .playlist,
                createPlaylist: createPlaylist
            )
            showToast("Aggiunto alla coda delle richieste del PC!")
            playlistUrlInput = ""
            return
        }

        isProcessingPlaylist = true
        playlistStatusText = isSingle ? "Scarico la singola traccia..." : "Analisi playlist in corso..."

        Task {
            let count = await sync.importSpotifyPlaylist(
                url,
                delegateToPc: false,
                createPlaylist: createPlaylist,
                onStatus: { step in
                    DispatchQueue.main.async {
                        self.playlistStatusText = step
                    }
                }
            )

            await MainActor.run {
                isProcessingPlaylist = false
                if count > 0 {
                    showToast("Operazione completata! (\(count) brani aggiunti)")
                    playlistUrlInput = ""
                } else {
                    showToast("Analisi completata o nessun brano scaricato.")
                }
            }
        }
    }

    // MARK: - 3. Sync Progress Card
    private func syncProgressCard(_ p: SyncProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(AppTheme.primary)
                Text("SINCRONIZZAZIONE PC IN CORSO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                Spacer()
                Text("\(Int(p.progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.primary)
            }

            if let task = p.currentTask, !task.isEmpty {
                Text(task)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            ProgressView(value: p.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primary))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            HStack {
                if p.totalTracks > 0 {
                    Text("Traccia \(p.currentTrack) di \(p.totalTracks)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Button(action: {
                    Task {
                        await sync.cancelCurrentSync()
                        showToast("Sincronizzazione annullata")
                    }
                }) {
                    Text("Annulla")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surfaceLight)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.primary.opacity(0.4), lineWidth: 1))
    }

    // MARK: - 4. Download Queue Card
    private var downloadQueueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .foregroundColor(AppTheme.primary)
                Text("CODA RICHIESTE PC (\(queue.jobs.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                Spacer()
                Button(action: { queue.clearQueue() }) {
                    Text("Svuota")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                }
            }

            VStack(spacing: 8) {
                ForEach(queue.jobs) { job in
                    HStack(spacing: 10) {
                        Image(systemName: job.kind == .playlist ? "music.note.list" : "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(job.statusText)
                                .font(.system(size: 10))
                                .foregroundColor(job.status == .inCorso ? AppTheme.primary : AppTheme.textMuted)
                        }

                        Spacer()

                        Button(action: { queue.remove(id: job.id) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - 5. Wi-Fi Quick Card
    private var wifiQuickCard: some View {
        NavigationLink(destination: WifiServerView()) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(wifi.isRunning ? .green : AppTheme.textMuted)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Server Wi-Fi PC")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(wifi.isRunning ? "Attivo: \(wifi.serverUrl)" : "Non attivo • Trascina musica da browser PC")
                        .font(.system(size: 11))
                        .foregroundColor(wifi.isRunning ? .green : AppTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(14)
            .background(AppTheme.surfaceCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
        }
    }

    // MARK: - 6. Search Hub Card
    private var searchHubCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CENTRO RICERCA MULTI-PIATTAFORMA")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textMuted)

            // Segmented Picker
            Picker("", selection: $selectedSearchTab) {
                Text("YouTube").tag(0)
                Text("Spotify").tag(1)
                Text("SoundCloud").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())

            HStack {
                TextField("Cerca brano o artista...", text: $searchQuery)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit { performSearch() }

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Button(action: { performSearch() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(AppTheme.primary)
                        .cornerRadius(8)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder, lineWidth: 1))
        }
        .padding(16)
        .background(AppTheme.surfaceCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    private func performSearch() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        isSearching = true
        searchError = nil

        Task {
            do {
                if selectedSearchTab == 0 {
                    let res = try await YouTubeService.shared.search(q)
                    await MainActor.run {
                        self.youtubeResults = res
                        self.isSearching = false
                        if res.isEmpty { searchError = "Nessun risultato YouTube trovato per \"\(q)\"" }
                    }
                } else if selectedSearchTab == 1 {
                    let res = try await SpotifyService.shared.search(q)
                    await MainActor.run {
                        self.spotifyResults = res
                        self.isSearching = false
                        if res.isEmpty { searchError = "Nessun risultato Spotify trovato per \"\(q)\"" }
                    }
                } else {
                    let res = try await SoundCloudService.shared.search(q)
                    await MainActor.run {
                        self.soundCloudResults = res
                        self.isSearching = false
                        if res.isEmpty { searchError = "Nessun risultato SoundCloud trovato per \"\(q)\"" }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.searchError = "Errore ricerca: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Search Results List
    @ViewBuilder
    private var searchResultsList: some View {
        if selectedSearchTab == 0 {
            ForEach(youtubeResults) { track in
                youtubeResultTile(track)
            }
        } else if selectedSearchTab == 1 {
            ForEach(spotifyResults) { item in
                spotifyResultTile(item)
            }
        } else {
            ForEach(soundCloudResults) { track in
                soundCloudResultTile(track)
            }
        }
    }

    private func youtubeResultTile(_ yt: YouTubeTrack) -> some View {
        HStack(spacing: 12) {
            TrackArtworkView(artworkPath: yt.thumbnailUrl, title: yt.title, size: 50, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(yt.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text("\(yt.author) • \(yt.formattedDuration)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                // Play stream
                Button(action: {
                    let track = yt.toTrack()
                    AudioPlayerService.shared.play(track: track, from: [track])
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.primary)
                }

                // Download locally
                Button(action: {
                    Task {
                        showToast("Download in corso: \(yt.title)")
                        let file = await YouTubeService.shared.downloadAudioStream(yt.id, yt.title)
                        if file != nil {
                            await LibraryService.shared.scanLibrary()
                            showToast("Scaricato con successo!")
                        } else {
                            showToast("Errore download. Prova a delegare al PC.")
                        }
                    }
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Enqueue on PC
                if sync.isConnected {
                    Button(action: {
                        queue.enqueue(
                            url: "https://www.youtube.com/watch?v=\(yt.id)",
                            label: yt.title,
                            kind: .singolo
                        )
                        showToast("Accodato sul PC!")
                    }) {
                        Image(systemName: "laptopcomputer.and.arrow.down")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
        }
        .padding(10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 1))
    }

    private func spotifyResultTile(_ item: SpotifyItem) -> some View {
        HStack(spacing: 12) {
            TrackArtworkView(artworkPath: item.artworkUrl, title: item.title, size: 50, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(item.artist)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if sync.isConnected {
                Button(action: {
                    queue.enqueue(url: item.url, label: "\(item.title) - \(item.artist)", kind: .singolo)
                    showToast("Accodato su PC per il download!")
                }) {
                    Text("Scarica su PC")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: 0x1DB954))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            } else {
                Button(action: {
                    UIPasteboard.general.string = item.url
                    showToast("Link copiato negli appunti!")
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .padding(10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 1))
    }

    private func soundCloudResultTile(_ sc: SoundCloudTrack) -> some View {
        HStack(spacing: 12) {
            TrackArtworkView(artworkPath: sc.artworkUrl, title: sc.title, size: 50, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(sc.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(sc.user)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if sync.isConnected {
                Button(action: {
                    queue.enqueue(url: sc.permalinkUrl, label: "\(sc.title) - \(sc.user)", kind: .singolo)
                    showToast("Accodato su PC per il download!")
                }) {
                    Text("Scarica su PC")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: 0xFF5500))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Button(action: {
                    UIPasteboard.general.string = sc.permalinkUrl
                    showToast("Link SoundCloud copiato!")
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .padding(10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder.opacity(0.6), lineWidth: 1))
    }
}
