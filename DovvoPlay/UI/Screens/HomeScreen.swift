import SwiftUI

public struct HomeScreen: View {
    @State private var selectedTab: Int = 1 // 0: Playlist, 1: Libreria (Default), 2: Impostazioni
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var updateService = UpdateService.shared

    // Update modal
    @State private var availableRelease: AppReleaseInfo? = nil
    @State private var showingUpdateSheet: Bool = false
    @State private var isDownloadingUpdate: Bool = false
    @State private var updateDownloadProgress: Double = 0.0
    @State private var updateStatusText: String = ""

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Tabs
            TabView(selection: $selectedTab) {
                PlaylistTab()
                    .tag(0)
                    .tabItem {
                        Label("Playlist", systemImage: "music.note.list")
                    }

                LibraryTab()
                    .tag(1)
                    .tabItem {
                        Label("Libreria", systemImage: "music.note.house.fill")
                    }

                SettingsTab()
                    .tag(2)
                    .tabItem {
                        Label("Impostazioni", systemImage: "gearshape.fill")
                    }
            }
            .tint(AppTheme.primary)

            // Floating MiniPlayer docked above the TabBar
            if player.currentTrack != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Height of standard iOS TabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: 0x0A0A0A))
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }

            // Silent update check
            Task {
                if let release = await updateService.checkForUpdates(isSilent: true), release.isNewer {
                    await MainActor.run {
                        self.availableRelease = release
                        self.showingUpdateSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingUpdateSheet) {
            if let release = availableRelease {
                updateModalView(release)
            }
        }
    }

    // MARK: - Update Modal
    private func updateModalView(_ release: AppReleaseInfo) -> some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 34))
                        .foregroundColor(AppTheme.primary)
                }
                .padding(.top, 16)

                VStack(spacing: 4) {
                    Text("Nuovo Aggiornamento!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Versione \(release.tagName) disponibile (Attuale: \(UpdateService.currentVersion))")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Changelog Card
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOVITÀ IN QUESTA VERSIONE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.primary)

                        Text(release.body.isEmpty ? "Miglioramenti generali e ottimizzazioni di sistema." : release.body)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfaceCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                }
                .frame(maxHeight: 220)

                // Progress or Download Button
                if isDownloadingUpdate {
                    VStack(spacing: 6) {
                        ProgressView(value: updateDownloadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primary))
                        Text(updateStatusText.isEmpty ? "Scaricamento in corso..." : updateStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.horizontal, 20)
                } else {
                    Button(action: {
                        startUpdateDownload(release)
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Scarica Pacchetto .ipa Ora")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.primaryGradient)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 16)
                }

                Button(action: {
                    showingUpdateSheet = false
                }) {
                    Text("Più tardi")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.bottom, 12)
            }
            .padding(20)
        }
    }

    private func startUpdateDownload(_ release: AppReleaseInfo) {
        isDownloadingUpdate = true
        updateStatusText = "Avvio download pacchetto .ipa..."

        Task {
            let fileUrl = await updateService.downloadIpa(release) { prog, status in
                DispatchQueue.main.async {
                    self.updateDownloadProgress = prog
                    self.updateStatusText = status
                }
            }

            await MainActor.run {
                self.isDownloadingUpdate = false
                if let file = fileUrl {
                    self.showingUpdateSheet = false
                    updateService.shareFile(file)
                } else {
                    self.updateStatusText = "Errore durante il download del pacchetto."
                }
            }
        }
    }
}
