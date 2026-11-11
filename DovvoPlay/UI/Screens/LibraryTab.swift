import SwiftUI
import UniformTypeIdentifiers

public enum TrackSortMode: String, CaseIterable, Identifiable {
    public var id: String { rawValue }

    case none = "Nessuno"
    case duration = "Durata"
    case playCount = "Ascolti Totali"
    case artist = "Artista"

    public var systemImage: String {
        switch self {
        case .none: return "line.3.horizontal.decrease"
        case .duration: return "clock"
        case .playCount: return "flame.fill"
        case .artist: return "person.fill"
        }
    }
}

public struct LibraryTab: View {
    @ObservedObject private var lib = LibraryService.shared
    @ObservedObject private var stats = StatsService.shared
    @ObservedObject private var viewModeService = ViewModeService.shared
    @ObservedObject private var themeService = ThemeService.shared
    @ObservedObject private var player = AudioPlayerService.shared

    @State private var filterText: String = ""
    @State private var activeCategory: String = "all" // all, top, least, recent
    @State private var sortMode: TrackSortMode = .none
    @State private var indexOpen: Bool = false
    @State private var pressedLetter: String? = nil

    @State private var showingFileImporter: Bool = false
    @State private var showingMagicShuffleSheet: Bool = false
    @State private var showingStatsView: Bool = false
    @State private var toastMessage: String? = nil

    public init() {}

    private var baseTracks: [Track] {
        switch activeCategory {
        case "top":
            return stats.getMostPlayedTracks(from: lib.tracks)
        case "least":
            return stats.getLeastPlayedTracks(from: lib.tracks)
        case "recent":
            return stats.getRecentlyPlayedTracks(from: lib.tracks)
        default:
            return lib.tracks
        }
    }

    private var filteredAndSortedTracks: [Track] {
        var result = baseTracks
        if !filterText.isEmpty {
            let lower = filterText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lower) || $0.artist.lowercased().contains(lower)
            }
        }

        switch sortMode {
        case .duration:
            result.sort { $0.durationMs > $1.durationMs }
        case .playCount:
            result.sort { (stats.getStat($0.id)?.totalDurationSeconds ?? 0) > (stats.getStat($1.id)?.totalDurationSeconds ?? 0) }
        case .artist:
            result.sort { $0.displayArtist.localizedCaseInsensitiveCompare($1.displayArtist) == .orderedAscending }
        case .none:
            break
        }
        return result
    }

    private var indexLetters: [String] {
        let tracks = filteredAndSortedTracks
        var seen = [String]()
        for t in tracks {
            let key: String
            if sortMode == .artist {
                let a = t.displayArtist.trimmingCharacters(in: .whitespacesAndNewlines)
                key = a.isEmpty ? "#" : String(a.prefix(1)).uppercased()
            } else if sortMode == .duration {
                key = "\(Int(t.duration / 60))"
            } else {
                let title = t.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let first = title.first, first.isLetter {
                    key = String(first).uppercased()
                } else {
                    key = "#"
                }
            }
            if !seen.contains(key) {
                seen.append(key)
            }
        }
        return seen
    }

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                // Magic Shuffle & Stats Insight Cards
                                if !lib.tracks.isEmpty {
                                    HStack(spacing: 10) {
                                        // Magic Shuffle Button
                                        Button(action: {
                                            showingMagicShuffleSheet = true
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.black)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Shuffle Magico")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(.black)
                                                    Text("\(stats.todayStat.listeningSeconds / 60)m ascoltati oggi")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(Color.black.opacity(0.75))
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(AppTheme.primaryGradient)
                                                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 3)
                                            )
                                        }
                                        .frame(maxWidth: .infinity)

                                        // Insight Card
                                        NavigationLink(destination: StatsView()) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "chart.bar.xaxis")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(AppTheme.primary)
                                                Text(stats.totalListeningSeconds > 0 ? stats.formatDurationSummary() : "Insight")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(AppTheme.textPrimary)
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(AppTheme.surfaceCard)
                                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 6)
                                }

                                // Search Field with "A" Index Button
                                if !lib.tracks.isEmpty {
                                    HStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundColor(AppTheme.primary)
                                                .font(.system(size: 15, weight: .bold))

                                            TextField("Cerca tra i brani locali...", text: $filterText)
                                                .foregroundColor(AppTheme.textPrimary)
                                                .font(.system(size: 14))

                                            if !filterText.isEmpty {
                                                Button(action: { filterText = "" }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(AppTheme.textSecondary)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(AppTheme.surfaceCard)
                                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
                                        )

                                        // "A" Alphabet Index Button
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                indexOpen.toggle()
                                            }
                                        }) {
                                            Text("A")
                                                .font(.system(size: 16, weight: .black))
                                                .foregroundColor(indexOpen ? .black : AppTheme.textSecondary)
                                                .frame(width: 42, height: 42)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(indexOpen ? AppTheme.primary : AppTheme.surfaceCard)
                                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(indexOpen ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1))
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }

                                // Quick Category Filter Pills
                                if !lib.tracks.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            categoryPill(id: "all", title: "Tutti i brani", icon: "music.note")
                                            categoryPill(id: "top", title: "🔥 Più ascoltate", icon: "flame.fill")
                                            categoryPill(id: "least", title: "💎 Da riscoprire", icon: "safari.fill")
                                            categoryPill(id: "recent", title: "🕒 Recenti", icon: "clock")
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }

                                // Sort Pills
                                if !lib.tracks.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            Text("ORDINA:")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(AppTheme.textSecondary)
                                                .padding(.trailing, 2)

                                            ForEach(TrackSortMode.allCases) { mode in
                                                let isSelected = sortMode == mode
                                                Button(action: {
                                                    sortMode = mode
                                                }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: mode.systemImage)
                                                            .font(.system(size: 10))
                                                        Text(mode.rawValue)
                                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                                    }
                                                    .foregroundColor(isSelected ? .black : AppTheme.textPrimary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .fill(isSelected ? AppTheme.primary : AppTheme.surfaceCard)
                                                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1))
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }

                                // Tracks Container
                                if lib.tracks.isEmpty {
                                    emptyStateView
                                } else {
                                    tracksListView(tracks: filteredAndSortedTracks)
                                        .padding(.bottom, 120) // space for MiniPlayer
                                }
                            }
                        }
                        .refreshable {
                            await lib.scanLibrary()
                        }
                        .overlay(
                            // Alphabetical Index Scrubber Overlay
                            Group {
                                if indexOpen && !indexLetters.isEmpty {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 2) {
                                            ForEach(indexLetters, id: \.self) { letter in
                                                Text(letter)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(pressedLetter == letter ? AppTheme.primary : AppTheme.textSecondary)
                                                    .frame(width: 22, height: 18)
                                                    .onTapGesture {
                                                        pressedLetter = letter
                                                        if let targetTrack = filteredAndSortedTracks.first(where: { trackMatchesKey($0, key: letter) }) {
                                                            withAnimation(.easeOut(duration: 0.25)) {
                                                                proxy.scrollTo(targetTrack.id, anchor: .top)
                                                            }
                                                        }
                                                    }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(AppTheme.surfaceCard.opacity(0.95))
                                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
                                        )
                                        .padding(.trailing, 4)
                                    }
                                }
                            }
                        )
                    }
                }

                // Toast Notification
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.surfaceCard)
                                    .overlay(Capsule().stroke(AppTheme.primary, lineWidth: 1))
                                    .shadow(radius: 8)
                            )
                            .padding(.bottom, 110)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Text("Libreria")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("\(lib.tracks.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.primary.opacity(0.15))
                            .cornerRadius(10)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Quick Palette Cycle Button
                    Button(action: {
                        themeService.cycleNextTheme()
                        showToast("Tema: \(themeService.currentTheme.name)")
                    }) {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(AppTheme.primary)
                    }

                    // Quick View Mode Cycle Button
                    Button(action: {
                        viewModeService.cycleNextMode()
                        showToast("Layout: \(viewModeService.currentInfo.name)")
                    }) {
                        Image(systemName: viewModeService.currentInfo.systemImage)
                            .foregroundColor(AppTheme.primary)
                    }

                    // Import Files Button
                    Button(action: {
                        showingFileImporter = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.audio, .mp3],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    let musicDir = lib.musicDirectory
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        let dest = musicDir.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.copyItem(at: url, to: dest)
                    }
                    Task {
                        await lib.scanLibrary()
                    }
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $showingMagicShuffleSheet) {
                MagicShuffleSheetView(tracks: lib.tracks)
            }
        }
    }

    private func categoryPill(id: String, title: String, icon: String) -> some View {
        let isSelected = activeCategory == id
        return Button(action: {
            activeCategory = id
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .black : AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppTheme.primary : AppTheme.surfaceCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1))
            )
        }
    }

    @ViewBuilder
    private func tracksListView(tracks: [Track]) -> some View {
        switch viewModeService.currentMode {
        case .gridCovers:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(track: track, queue: tracks, mode: .gridCovers, index: index) {
                        player.playTrack(track, newQueue: tracks)
                    }
                    .id(track.id)
                }
            }
            .padding(.horizontal, 16)
        case .gridCompact:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(track: track, queue: tracks, mode: .gridCompact, index: index) {
                        player.playTrack(track, newQueue: tracks)
                    }
                    .id(track.id)
                }
            }
            .padding(.horizontal, 16)
        default:
            LazyVStack(spacing: 8) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(track: track, queue: tracks, mode: viewModeService.currentMode, index: index) {
                        player.playTrack(track, newQueue: tracks)
                    }
                    .id(track.id)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceCard)
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(AppTheme.goldBorder, lineWidth: 1.5))
                Image(systemName: "music.note.list")
                    .font(.system(size: 42))
                    .foregroundColor(AppTheme.primary)
            }

            Text("Nessun brano salvato")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text("Carica file dal computer via Wi-Fi\no scarica brani da YouTube nella sezione Impostazioni!")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                showingFileImporter = true
            }) {
                Label("Importa da File / iCloud", systemImage: "folder.badge.plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(AppTheme.primary)
                    )
            }
            .padding(.top, 8)
            Spacer(minLength: 60)
        }
    }

    private func trackMatchesKey(_ track: Track, key: String) -> Bool {
        if sortMode == .artist {
            let a = track.displayArtist.trimmingCharacters(in: .whitespacesAndNewlines)
            return (a.isEmpty ? "#" : String(a.prefix(1)).uppercased()) == key
        }
        if sortMode == .duration {
            return "\(Int(track.duration / 60))" == key
        }
        let title = track.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = title.first, first.isLetter {
            return String(first).uppercased() == key
        }
        return key == "#"
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if toastMessage == msg {
                withAnimation { toastMessage = nil }
            }
        }
    }
}

private struct MagicShuffleSheetView: View {
    let tracks: [Track]
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    shuffleOption(mode: .magic, title: "🔮 Shuffle Magico", subtitle: "Bilancia preferite, medie e perle dimenticate", color: AppTheme.primary)
                    shuffleOption(mode: .mostPlayed, title: "🔥 Hit Parade", subtitle: "Brani più ascoltati e ripetuti", color: Color.orange)
                    shuffleOption(mode: .leastPlayed, title: "💎 Riscopri", subtitle: "Brani mai o meno ascoltati", color: Color.teal)
                    shuffleOption(mode: .mediumPlayed, title: "⚖️ Equilibrato", subtitle: "Brani nella fascia media di ascolto", color: Color.blue)
                    shuffleOption(mode: .recent, title: "⏳ Freschi & Recenti", subtitle: "Brani aggiunti o ascoltati ultimamente", color: Color.purple)
                    shuffleOption(mode: .standard, title: "🎲 Casuale 100%", subtitle: "Mescola tutti i brani casualmente", color: AppTheme.textSecondary)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Scegli Shuffle Magico")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func shuffleOption(mode: ShuffleMode, title: String, subtitle: String, color: Color) -> some View {
        Button(action: {
            player.setShuffleMode(mode, baseList: tracks)
            if let first = player.queue.first {
                player.playTrack(first)
            }
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 14) {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: mode.systemImage).foregroundColor(color))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppTheme.surfaceCard)
    }
}
