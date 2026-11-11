import SwiftUI

public struct WifiServerView: View {
    @ObservedObject private var wifi = WifiServerService.shared
    @State private var toastMessage: String? = nil

    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Server Status Card
                    statusCard

                    // Istruzioni d'uso
                    instructionsCard

                    // Upload recenti (se presenti)
                    if !wifi.recentUploads.isEmpty {
                        recentUploadsCard
                    }
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
        .navigationTitle("Server Wi-Fi PC")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wifi.updateIpAddress()
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

    // MARK: - Server Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(wifi.isRunning ? AppTheme.primary.opacity(0.15) : Color.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle().stroke(wifi.isRunning ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1.5)
                    )

                Image(systemName: wifi.isRunning ? "wifi" : "wifi.slash")
                    .font(.system(size: 38))
                    .foregroundColor(wifi.isRunning ? AppTheme.primary : AppTheme.textSecondary)
            }
            .padding(.top, 8)

            // Title & Subtitle
            VStack(spacing: 4) {
                Text(wifi.isRunning ? "Server Attivo" : "Server Non Attivo")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(wifi.isRunning ? AppTheme.primary : AppTheme.textPrimary)

                Text(wifi.isRunning
                     ? "Raggiungibile dai computer sulla stessa rete Wi-Fi"
                     : "Attiva il server per caricare musica direttamente dal tuo browser PC")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Server Address Box (if running)
            if wifi.isRunning {
                HStack {
                    Text(wifi.serverUrl)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.primary)
                        .lineLimit(1)

                    Spacer()

                    Button(action: {
                        UIPasteboard.general.string = wifi.serverUrl
                        showToast("Indirizzo copiato negli appunti!")
                    }) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primary)
                            .padding(8)
                            .background(AppTheme.surfaceLight)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.goldBorder, lineWidth: 1))
            }

            // Toggle Button
            Button(action: {
                Task {
                    await wifi.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: wifi.isRunning ? "stop.fill" : "play.fill")
                    Text(wifi.isRunning ? "Spegni Server" : "Accendi Server Wi-Fi")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(wifi.isRunning ? Color.red.opacity(0.85) : AppTheme.primary)
                .foregroundColor(wifi.isRunning ? .white : .black)
                .cornerRadius(16)
                .shadow(color: wifi.isRunning ? Color.red.opacity(0.3) : AppTheme.primary.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(20)
        .background(AppTheme.goldSurfaceGradient)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(wifi.isRunning ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1.3)
        )
    }

    // MARK: - Instructions Card
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COME TRASFERIRE MUSICA DAL PC")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.secondary)
                .tracking(1.2)

            VStack(spacing: 12) {
                stepRow(
                    step: "1",
                    title: "Connetti iPhone e PC alla stessa rete Wi-Fi",
                    subtitle: "Entrambi i dispositivi devono trovarsi sullo stesso modem o router."
                )

                stepRow(
                    step: "2",
                    title: "Accendi il server e apri l'indirizzo sul PC",
                    subtitle: "Apri Chrome, Safari, Edge o Firefox sul PC e inserisci http://\(wifi.ipAddress):8080"
                )

                stepRow(
                    step: "3",
                    title: "Trascina i tuoi file audio nella pagina",
                    subtitle: "Supporta MP3, M4A, AAC, FLAC, WAV. Verranno estratti automaticamente titolo, artista e copertine."
                )

                stepRow(
                    step: "4",
                    title: "Ascolta subito senza cavi!",
                    subtitle: "I brani saranno subito disponibili nella scheda Libreria senza bisogno di iTunes o sincronizzazioni."
                )
            }
        }
        .padding(18)
        .background(AppTheme.surfaceCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1))
    }

    private func stepRow(step: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 22, height: 22)
                .background(AppTheme.primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Recent Uploads Card
    private var recentUploadsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(AppTheme.primary)
                Text("FILE TRASFERITI DI RECENTE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                Spacer()
                Text("\(wifi.recentUploads.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textMuted)
            }

            VStack(spacing: 8) {
                ForEach(wifi.recentUploads.suffix(10).reversed(), id: \.self) { filename in
                    HStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.primary)

                        Text(filename)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(AppTheme.surfaceCard)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.goldBorder, lineWidth: 1))
    }
}
