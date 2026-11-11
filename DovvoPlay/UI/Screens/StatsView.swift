import SwiftUI

public enum StatPeriodView: Int {
    case day = 0
    case month = 1
    case year = 2
}

public struct StatsView: View {
    @ObservedObject private var statsService = StatsService.shared
    @ObservedObject private var lib = LibraryService.shared

    @State private var selectedPeriod: StatPeriodView = .day
    @State private var currentDate: Date = Date()

    @State private var showingResetStep1: Bool = false
    @State private var showingResetStep2: Bool = false
    @State private var toastMessage: String? = nil

    public init() {}

    private var currentPeriodStat: PeriodStat {
        let cal = Calendar.current
        switch selectedPeriod {
        case .day:
            return statsService.getStatForDay(currentDate)
        case .month:
            let year = cal.component(.year, from: currentDate)
            let month = cal.component(.month, from: currentDate)
            return statsService.getStatForMonth(year, month)
        case .year:
            let year = cal.component(.year, from: currentDate)
            return statsService.getStatForYear(year)
        }
    }

    private var isCurrentPeriod: Bool {
        let cal = Calendar.current
        let now = Date()
        switch selectedPeriod {
        case .day:
            return cal.isDate(currentDate, inSameDayAs: now)
        case .month:
            return cal.component(.year, from: currentDate) == cal.component(.year, from: now) &&
                   cal.component(.month, from: currentDate) == cal.component(.month, from: now)
        case .year:
            return cal.component(.year, from: currentDate) == cal.component(.year, from: now)
        }
    }

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 1. Selettore Vista: Giorno / Mese / Anno
                    periodSegmentSelector

                    // 2. Navigatore Data (< Periodo >)
                    periodNavigator

                    // 3. Banner Mood & Esito del Periodo
                    moodBanner(currentPeriodStat.getMood())

                    // 4. KPI Tempo di Ascolto e Brani Totali
                    kpiSection(currentPeriodStat)

                    // 5. Le 4 Categorie di Ascolto (0-15%, 15-35%, 35-70%, 70-100%)
                    categoriesCard(currentPeriodStat)

                    // 6. Top 5 Brani più ascoltati (70-100%)
                    rankingsSection(
                        title: "🏆 Top 5 Brani più Ascoltati (70-100%)",
                        subtitle: "Canzoni ascoltate con entusiasmo in questo periodo",
                        trackCounts: currentPeriodStat.trackPlays,
                        isPositive: true,
                        emptyText: "Nessun brano ha superato il 70% di ascolto."
                    )

                    // 7. Brani più skippati (0-15%)
                    rankingsSection(
                        title: "⏭️ Brani più Skippati (0-15%)",
                        subtitle: "Canzoni saltate nei primi secondi",
                        trackCounts: currentPeriodStat.trackSkips,
                        isPositive: false,
                        emptyText: "Nessun brano skippato in questo periodo!"
                    )

                    // 8. Top Artisti
                    topArtistsSection(currentPeriodStat)

                    // 9. Reset Totale Statistiche
                    resetStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
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
                    .background(AppTheme.primary)
                    .cornerRadius(24)
                    .shadow(radius: 8)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .navigationTitle("Statistiche d'Ascolto")
        .navigationBarTitleDisplayMode(.inline)
        .alert("SEI VERAMENTE SICURO?", isPresented: $showingResetStep1) {
            Button("Annulla", role: .cancel) {}
            Button("CONFERMA PASSAGGIO 1", role: .destructive) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingResetStep2 = true
                }
            }
        } message: {
            Text("Stai per cancellare tutte le statistiche di ascolto, i secondi registrati, i conteggi skip e le classifiche storiche.")
        }
        .alert("ULTIMA CONFERMA: AZIONE IRREVERSIBILE!", isPresented: $showingResetStep2) {
            Button("Annulla", role: .cancel) {}
            Button("ELIMINA DEFINITIVAMENTE TUTTO", role: .destructive) {
                statsService.resetAllStats()
                showToast("Tutte le statistiche sono state azzerate.")
            }
        } message: {
            Text("Tutti i secondi e i riepiloghi andranno persi per sempre. Sei assolutamente certo di voler cancellare tutto?")
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

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        return "\(minutes)m \(seconds)s"
    }

    // MARK: - 1. Period Selector
    private var periodSegmentSelector: some View {
        HStack(spacing: 6) {
            periodButton(view: .day, title: "📅 GIORNO")
            periodButton(view: .month, title: "🗓️ MESE")
            periodButton(view: .year, title: "📆 ANNO")
        }
        .padding(4)
        .background(AppTheme.surfaceCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    private func periodButton(view: StatPeriodView, title: String) -> some View {
        let isSelected = selectedPeriod == view
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPeriod = view
                currentDate = Date()
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.primary : Color.clear)
                .cornerRadius(10)
        }
    }

    // MARK: - 2. Period Navigator
    private var periodNavigator: some View {
        HStack {
            Button(action: {
                navigatePeriod(direction: -1)
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.primary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(currentPeriodStat.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                if isCurrentPeriod {
                    Text("Oggi / In corso")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                }
            }

            Spacer()

            Button(action: {
                navigatePeriod(direction: 1)
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isCurrentPeriod ? AppTheme.textMuted : AppTheme.primary)
            }
            .disabled(isCurrentPeriod)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    private func navigatePeriod(direction: Int) {
        let cal = Calendar.current
        let now = Date()
        var newDate: Date?

        switch selectedPeriod {
        case .day:
            newDate = cal.date(byAdding: .day, value: direction, to: currentDate)
        case .month:
            newDate = cal.date(byAdding: .month, value: direction, to: currentDate)
        case .year:
            newDate = cal.date(byAdding: .year, value: direction, to: currentDate)
        }

        if let validDate = newDate {
            if validDate <= now {
                withAnimation {
                    currentDate = validDate
                }
            }
        }
    }

    // MARK: - 3. Mood Banner
    private func moodBanner(_ mood: DailyMoodOutcome) -> some View {
        HStack(spacing: 14) {
            Image(systemName: mood.systemImage)
                .font(.system(size: 32))
                .foregroundColor(mood.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(mood.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(mood.message)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.goldSurfaceGradient)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1.2))
    }

    // MARK: - 4. KPI Section
    private func kpiSection(_ period: PeriodStat) -> some View {
        HStack(spacing: 10) {
            kpiCard(
                title: "TEMPO TOTALE",
                value: formatDuration(period.listeningSeconds),
                icon: "clock.fill",
                color: AppTheme.primary
            )

            kpiCard(
                title: "BRANI ASCOLTATI",
                value: "\(period.completedCount)",
                icon: "checkmark.seal.fill",
                color: Color.green
            )

            kpiCard(
                title: "SKIP TOTALI",
                value: "\(period.skipsCount)",
                icon: "forward.end.alt.fill",
                color: Color.red
            )
        }
    }

    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textMuted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - 5. Categories Card
    private func categoriesCard(_ period: PeriodStat) -> some View {
        let total = max(1, period.totalInteractions)

        return VStack(alignment: .leading, spacing: 12) {
            Text("COMPORTAMENTO D'ASCOLTO PER FASCE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.primary)

            tierRow(
                label: "0% - 15% (Skip immediato)",
                count: period.skipsCount,
                percent: Double(period.skipsCount) / Double(total),
                color: .red
            )

            tierRow(
                label: "15% - 35% (Breve assaggio)",
                count: period.briefCount,
                percent: Double(period.briefCount) / Double(total),
                color: .orange
            )

            tierRow(
                label: "35% - 70% (Ascolto medio)",
                count: period.halfCount,
                percent: Double(period.halfCount) / Double(total),
                color: .blue
            )

            tierRow(
                label: "70% - 100% (Ascolto completo)",
                count: period.completedCount,
                percent: Double(period.completedCount) / Double(total),
                color: .green
            )
        }
        .padding(16)
        .background(AppTheme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    private func tierRow(label: String, count: Int, percent: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(count) (\(Int(percent * 100))%)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            ProgressView(value: percent)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
    }

    // MARK: - 6 & 7. Rankings Section
    private func rankingsSection(
        title: String,
        subtitle: String,
        trackCounts: [String: Int],
        isPositive: Bool,
        emptyText: String
    ) -> some View {
        let sortedTracks = trackCounts.sorted { $0.value > $1.value }.prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }

            if sortedTracks.isEmpty {
                Text(emptyText)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(sortedTracks.enumerated()), id: \.element.key) { idx, item in
                        let track = lib.findTrack(id: item.key)
                        let title = track?.displayTitle ?? statsService.stats[item.key]?.title ?? "Brano \(item.key)"
                        let artist = track?.displayArtist ?? statsService.stats[item.key]?.artist ?? "Artista"
                        let artwork = track?.artworkPath ?? statsService.stats[item.key]?.thumbnailUrl

                        HStack(spacing: 10) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(isPositive ? AppTheme.primary : Color.red)
                                .frame(width: 24)

                            TrackArtworkView(artworkPath: artwork, title: title, size: 40, cornerRadius: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Text(artist)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(item.value)x")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(isPositive ? Color.green : Color.red)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - 8. Top Artists Section
    private func topArtistsSection(_ period: PeriodStat) -> some View {
        var artistPlays: [String: Int] = [:]
        for (trackId, count) in period.trackPlays {
            let track = lib.findTrack(id: trackId)
            let artist = track?.displayArtist ?? statsService.stats[trackId]?.artist ?? "Sconosciuto"
            if !artist.isEmpty && artist != "Artista sconosciuto" {
                artistPlays[artist] = (artistPlays[artist] ?? 0) + count
            }
        }

        let sortedArtists = artistPlays.sorted { $0.value > $1.value }.prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            Text("🎤 Top Artisti del Periodo")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            if sortedArtists.isEmpty {
                Text("Nessun dato artisti disponibile per questo periodo.")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(sortedArtists.enumerated()), id: \.element.key) { idx, item in
                        HStack {
                            Text("#\(idx + 1)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 24)

                            Text(item.key)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(item.value) ascolti")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    // MARK: - 9. Reset Stats Section
    private var resetStatsSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)

            Text("RESET STATISTICHE & STORICO")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.red)
                .tracking(1.1)

            Text("Cancella tutti i secondi registrati e le classifiche con 2 passaggi di sicurezza obbligatori.")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button(action: {
                showingResetStep1 = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("AZZERA TUTTE LE STATISTICHE")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }
}
