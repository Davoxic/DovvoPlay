import SwiftUI

/// Dice quali sorgenti rispondono adesso: serve quando "YouTube non va"
/// e bisogna capire se il problema è l'app, la rete o le istanze.
struct DiagnosticsView: View {
    @State var reports: [PipedClient.InstanceReport] = []
    @State var running = false
    @State var youtubeDirect: String = "non provato"
    @State var soundcloud: String = "non provato"
    @State var invidious: String = "non provato"

    var body: some View {
        List {
            Section {
                Button {
                    Task { await runAll() }
                } label: {
                    HStack {
                        Label(running ? "Sto provando…" : "Prova tutte le sorgenti",
                              systemImage: "stethoscope")
                        Spacer()
                        if running { ProgressView() }
                    }
                }
                .disabled(running)
            } footer: {
                Text("Ogni sorgente viene interrogata davvero, con una ricerca breve. Le istanze verdi sono quelle che l'app userà.")
            }

            Section("YouTube (Diretto)") {
                LabeledContent("Stato", value: youtubeDirect)
            }

            Section("SoundCloud") {
                LabeledContent("Stato", value: soundcloud)
            }

            Section("Invidious") {
                LabeledContent("Stato", value: invidious)
            }

            if !reports.isEmpty {
                Section("Istanze Piped") {
                    ForEach(reports) { report in
                        HStack(spacing: 10) {
                            Image(systemName: report.ok ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(report.ok ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.base.replacingOccurrences(of: "https://", with: ""))
                                    .font(.footnote)
                                    .lineLimit(1)
                                Text(report.ok ? "\(report.millis) ms" : "non risponde")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Diagnostica")
        .navigationBarTitleDisplayMode(.inline)
        .task { if reports.isEmpty { await runAll() } }
    }

    private func runAll() async {
        running = true
        youtubeDirect = "provo…"
        soundcloud = "provo…"
        invidious = "provo…"

        async let piped = PipedClient.probeAll()

        do {
            let found = try await YouTubeClient.search("music", allowBridge: false)
            youtubeDirect = found.isEmpty ? "risponde ma senza risultati" : "funziona (\(found.count) risultati)"
        } catch {
            youtubeDirect = "non funziona: \(error.localizedDescription)"
        }

        do {
            let found = try await SoundCloudClient.search("music", limit: 5)
            soundcloud = found.isEmpty ? "risponde ma senza risultati" : "funziona (\(found.count) risultati)"
        } catch {
            soundcloud = "non funziona: \(error.localizedDescription)"
        }

        do {
            let found = try await InvidiousClient.search("music")
            invidious = found.isEmpty ? "risponde ma senza risultati" : "funziona (\(found.count) risultati)"
        } catch {
            invidious = "nessuna istanza raggiungibile"
        }

        reports = await piped
        running = false
    }
}
