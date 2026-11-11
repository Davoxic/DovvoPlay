import SwiftUI
import UniformTypeIdentifiers

public struct SettingsTab: View {
    @ObservedObject private var lib = LibraryService.shared
    @ObservedObject private var themeService = ThemeService.shared
    @ObservedObject private var animService = AnimationThemeService.shared
    @ObservedObject private var viewService = ViewModeService.shared
    @ObservedObject private var updateService = UpdateService.shared

    @State private var showingEqualizer: Bool = false
    @State private var showingThemePicker: Bool = false
    @State private var showingAnimPicker: Bool = false
    @State private var showingViewModePicker: Bool = false
    @State private var showingImportTextAlert: Bool = false
    @State private var importJsonInput: String = ""
    @State private var showingFileImporter: Bool = false
    @State private var toastMessage: String? = nil

    public init() {}

    private var totalFileSize: Int {
        return lib.tracks.reduce(0) { $0 + ($1.fileSize ?? 0) }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Gold Edition VIP Header Card
                        vipHeaderCard

                        // Section 1: Transfer, Sources & PC Sync
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("FONTI, TRASFERIMENTO & PC SYNC")

                            NavigationLink(destination: PcCompanionView()) {
                                featureTile(
                                    title: "PC Companion & Sorgenti Web",
                                    subtitle: "Collega il PC via Wi-Fi, converti playlist Spotify e scarica da YouTube",
                                    badge: "LAN BACKEND",
                                    badgeColor: Color.blue,
                                    icon: "laptopcomputer",
                                    gradient: LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            }

                            NavigationLink(destination: YouTubeTabView()) {
                                featureTile(
                                    title: "YouTube Music Online",
                                    subtitle: "Cerca brani, streaming audio AAC istantaneo e download offline",
                                    badge: "ONLINE",
                                    badgeColor: Color.red,
                                    icon: "play.rectangle.fill",
                                    gradient: LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            }

                            NavigationLink(destination: WifiServerView()) {
                                featureTile(
                                    title: "Server Wi-Fi PC Integrato",
                                    subtitle: "Trascina brani da qualsiasi browser su PC a http://<ip>:8080",
                                    badge: "HTTP SERVER",
                                    badgeColor: Color.green,
                                    icon: "wifi.circle.fill",
                                    gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            }

                            Button(action: {
                                showingEqualizer = true
                            }) {
                                featureTile(
                                    title: "Equalizzatore Audio Hardware",
                                    subtitle: "5 bande frequenza (-12dB a +12dB), preamp gain e preset",
                                    badge: "AUDIO EQ",
                                    badgeColor: AppTheme.primary,
                                    icon: "slider.vertical.3",
                                    gradient: AppTheme.primaryGradient
                                )
                            }
                        }

                        // Section 2: Personalization & Themes
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("PERSONALIZZAZIONE & TEMI")

                            settingRow(
                                title: "Temi Visivi & Palette Colori (12+ Temi)",
                                subtitle: "Attuale: \(themeService.currentTheme.name)",
                                icon: "paintpalette.fill"
                            ) {
                                showingThemePicker = true
                            }

                            settingRow(
                                title: "Temi di Animazione Brani (16+ Effetti)",
                                subtitle: "Attuale: \(animService.currentTheme.name)",
                                icon: "sparkles"
                            ) {
                                showingAnimPicker = true
                            }

                            settingRow(
                                title: "Stile di Visualizzazione Libreria (8 Layout)",
                                subtitle: "Attuale: \(viewService.currentInfo.name)",
                                icon: "square.grid.2x2"
                            ) {
                                showingViewModePicker = true
                            }
                        }

                        // Section 3: Stats & Library
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("STATISTICHE & LIBRERIA")

                            NavigationLink(destination: StatsView()) {
                                settingRow(
                                    title: "Statistiche e Abitudini d'Ascolto",
                                    subtitle: "Classifica completa, percentuali reali di ascolto ed esito del giorno",
                                    icon: "chart.bar.xaxis"
                                )
                            }

                            settingRow(
                                title: "Riscansiona File Locali",
                                subtitle: "Rileva file musicali aggiunti ed estrai copertine ID3 / M4A",
                                icon: "arrow.triangle.2.circlepath"
                            ) {
                                Task {
                                    await lib.scanLibrary()
                                    showToast("Libreria aggiornata!")
                                }
                            }
                        }

                        // Section 4: Backup & Restore
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("SALVATAGGIO & BACKUP COMPLETO")

                            settingRow(
                                title: "Esporta Backup Completo (File & Appunti)",
                                subtitle: "Salva statistiche, abitudini, cronologia e playlist in formato JSON",
                                icon: "square.and.arrow.up"
                            ) {
                                do {
                                    let file = try BackupService.shared.exportToFile()
                                    UIPasteboard.general.string = BackupService.shared.createBackupJsonString()
                                    showToast("Backup salvato su file e appunti! (\(file.lastPathComponent))")
                                } catch {
                                    showToast("Errore salvataggio backup: \(error.localizedDescription)")
                                }
                            }

                            settingRow(
                                title: "Ripristina Backup da File (.json)",
                                subtitle: "Scegli il file di backup salvato in precedenza",
                                icon: "folder"
                            ) {
                                showingFileImporter = true
                            }

                            settingRow(
                                title: "Ripristina Backup da Testo o Appunti",
                                subtitle: "Incolla il contenuto JSON copiato in precedenza",
                                icon: "doc.on.clipboard"
                            ) {
                                importJsonInput = UIPasteboard.general.string ?? ""
                                showingImportTextAlert = true
                            }
                        }

                        // Section 5: GitHub Updates
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("AGGIORNAMENTI DA GITHUB")
                            updateCard
                        }

                        // App Info
                        VStack(spacing: 4) {
                            Text("DovvoPlay iOS Native Edition v2.0.0")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("100% Swift & AVFoundation • Nessun tracciamento dei tuoi dati")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 120) // space for MiniPlayer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Toast
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(AppTheme.surfaceCard).overlay(Capsule().stroke(AppTheme.primary, lineWidth: 1)))
                            .padding(.bottom, 110)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Impostazioni")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            .sheet(isPresented: $showingEqualizer) {
                EqualizerSheetView()
            }
            .sheet(isPresented: $showingThemePicker) {
                ThemePickerSheet()
            }
            .sheet(isPresented: $showingAnimPicker) {
                AnimationThemePickerSheet()
            }
            .sheet(isPresented: $showingViewModePicker) {
                ViewModePickerSheet()
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let file = urls.first {
                    guard file.startAccessingSecurityScopedResource() else { return }
                    defer { file.stopAccessingSecurityScopedResource() }
                    let res = BackupService.shared.importFromFile(file)
                    showToast(res.message)
                }
            }
            .alert("Ripristina Backup", isPresented: $showingImportTextAlert) {
                TextField("Incolla testo JSON qui", text: $importJsonInput)
                Button("Annulla", role: .cancel) {}
                Button("Ripristina") {
                    let res = BackupService.shared.importFromJsonString(importJsonInput)
                    showToast(res.message)
                }
            } message: {
                Text("Incolla i dati JSON del backup di DovvoPlay.")
            }
        }
    }

    private var vipHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.18))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(AppTheme.primary, lineWidth: 1.5))
                    Image(systemName: "star.fill")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("DOVVOPLAY GOLD")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(AppTheme.secondary)
                    Text(themeService.currentTheme.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            HStack {
                statItem(label: "Brani", value: "\(lib.tracks.count)")
                Divider().frame(height: 28).background(AppTheme.goldBorder)
                statItem(label: "Playlist", value: "\(lib.playlists.count)")
                Divider().frame(height: 28).background(AppTheme.goldBorder)
                statItem(label: "Spazio", value: formatBytes(totalFileSize))
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.goldBorder.opacity(0.4), lineWidth: 1))
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.surfaceGradient)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppTheme.goldBorder, lineWidth: 1.2))
                .shadow(color: AppTheme.primary.opacity(0.12), radius: 14, x: 0, y: 6)
        )
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(AppTheme.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.0)
            .foregroundColor(AppTheme.secondary)
            .padding(.horizontal, 4)
    }

    private func featureTile(
        title: String,
        subtitle: String,
        badge: String,
        badgeColor: Color,
        icon: String,
        gradient: LinearGradient
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(gradient)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(badge)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(badgeColor))
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
        )
    }

    private func settingRow(title: String, subtitle: String, icon: String, action: (() -> Void)? = nil) -> some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceLight)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surfaceCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
            )
        }
    }

    private var updateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(AppTheme.primary.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundColor(AppTheme.primary)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("DovvoPlay v\(UpdateService.currentVersion)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Compilazione unsigned automatica GitHub")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Button(action: {
                    Task {
                        _ = await updateService.checkForUpdates()
                    }
                }) {
                    Text(updateService.isChecking ? "Controllo..." : "Verifica")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.primary))
                }
            }

            if let rel = updateService.latestRelease {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ultima versione: \(rel.tagName)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(rel.isNewer ? AppTheme.primary : AppTheme.textSecondary)
                        Spacer()
                        if rel.isNewer {
                            Text("DISPONIBILE")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.primary))
                        }
                    }

                    if rel.isNewer {
                        if updateService.isDownloading {
                            VStack(alignment: .leading, spacing: 4) {
                                ProgressView(value: updateService.downloadProgress)
                                    .tint(AppTheme.primary)
                                Text(updateService.downloadStatus)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        } else if let ipaURL = updateService.downloadedIpaURL {
                            Button(action: {
                                updateService.shareIpa(fileURL: ipaURL)
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Firma con ESign / Scarlet / TrollStore")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.green))
                            }
                        } else {
                            Button(action: {
                                Task {
                                    if let file = await updateService.downloadIpa(release: rel) {
                                        updateService.shareIpa(fileURL: file)
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Scarica & Firma .ipa (\(formatBytes(rel.ipaSize)))")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(AppTheme.primary))
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1))
        )
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes <= 0 { return "0 B" }
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if toastMessage == msg {
                withAnimation { toastMessage = nil }
            }
        }
    }
}

private struct ThemePickerSheet: View {
    @ObservedObject private var themeService = ThemeService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(ThemeService.themes) { t in
                            let isSelected = themeService.currentTheme.id == t.id
                            Button(action: {
                                themeService.setTheme(id: t.id)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack(spacing: 14) {
                                    // Mini Theme Preview Card
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(t.isGradient ? t.darkGradient : LinearGradient(colors: [t.background], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 64, height: 46)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.goldBorder, lineWidth: 1))

                                        HStack(spacing: 4) {
                                            Circle().fill(t.primary).frame(width: 10, height: 10)
                                            Circle().fill(t.secondary).frame(width: 8, height: 8)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(t.name)
                                            .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                                            .foregroundColor(isSelected ? t.primary : AppTheme.textPrimary)
                                        Text(t.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(t.primary)
                                            .font(.system(size: 20))
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppTheme.surfaceCard)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? t.primary : AppTheme.goldBorder, lineWidth: isSelected ? 1.5 : 1))
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Temi Visivi & Palette")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AnimationThemePickerSheet: View {
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
            .navigationTitle("Temi Animazione")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ViewModePickerSheet: View {
    @ObservedObject private var viewService = ViewModeService.shared
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List(ViewModeService.modes) { m in
                    let isSelected = viewService.currentMode == m.mode
                    HStack(spacing: 14) {
                        Image(systemName: m.systemImage)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? AppTheme.primary : AppTheme.textPrimary)
                            Text(m.description)
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
                        viewService.setViewMode(m.mode)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Layout Libreria")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
