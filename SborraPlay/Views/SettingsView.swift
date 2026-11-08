import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var server = LocalServer.shared
    @AppStorage("serverAutoStart") var autoStart = false
    @State var showImporter = false
    @State var copied = false

    private var audioTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio, .mpeg4Movie]
        for id in ["org.xiph.flac", "public.m3u-playlist", "com.apple.m4a-audio", "public.aifc-audio"] {
            if let t = UTType(id) { types.append(t) }
        }
        return types
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                importSection
                librarySection
                aboutSection
            }
            .navigationTitle("Impostazioni")
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: audioTypes,
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    Task { await library.importFiles(urls) }
                case .failure(let error):
                    library.lastMessage = error.localizedDescription
                }
            }
            .onAppear { server.refreshAddresses() }
        }
    }

    // MARK: - sezioni

    private var serverSection: some View {
        Section {
            Toggle(isOn: Binding(get: { server.isRunning },
                                 set: { on in on ? server.start() : server.stop() })) {
                Label("Server Wi-Fi", systemImage: "wifi")
            }

            if server.isRunning {
                if server.addresses.isEmpty {
                    Label("Nessuna rete Wi-Fi rilevata", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    ForEach(server.addresses, id: \.self) { ip in
                        let url = "http://\(ip):\(server.port)"
                        Button {
                            UIPasteboard.general.string = url
                            copied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_600_000_000)
                                copied = false
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url).font(.body.monospaced())
                                    Text("Aprilo nel browser del computer")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundStyle(copied ? .green : .secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
                if server.uploadedCount > 0 {
                    Label("\(server.uploadedCount) file ricevuti in questa sessione",
                          systemImage: "arrow.down.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $autoStart) {
                Label("Accendi all'apertura dell'app", systemImage: "power")
            }

            if let error = server.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Trasferimento dal computer")
        } footer: {
            Text("Tieni l'app aperta mentre trasferisci. Il server è raggiungibile solo dai dispositivi sulla tua rete locale e non richiede password: spegnilo quando hai finito, soprattutto su reti pubbliche.")
        }
    }

    private var importSection: some View {
        Section {
            Button {
                showImporter = true
            } label: {
                Label("Importa da File / iCloud…", systemImage: "folder.badge.plus")
            }
            Button {
                Task { await library.rescan() }
            } label: {
                Label("Rileggi la cartella", systemImage: "arrow.clockwise")
            }
            .disabled(library.isScanning)
        } header: {
            Text("Import")
        } footer: {
            Text("Puoi anche copiare i file nella cartella SborraPlay tramite l'app File (Sul mio iPhone → SborraPlay) o dal Finder collegando il cavo.")
        }
    }

    private var librarySection: some View {
        Section("Libreria") {
            Picker("Ordinamento", selection: Binding(get: { library.sortMode },
                                                     set: { library.sortMode = $0 })) {
                ForEach(SortMode.allCases) { Text($0.label).tag($0) }
            }
            LabeledContent("Brani", value: "\(library.tracks.count)")
            LabeledContent("Playlist", value: "\(library.playlists.count)")
            LabeledContent("Durata totale", value: Track.timeString(library.totalDuration))
            LabeledContent("Spazio occupato", value: ByteCountFormatter.string(fromByteCount: library.totalBytes, countStyle: .file))
            if library.isScanning {
                HStack {
                    ProgressView()
                    Text("Scansione \(library.scanDone)/\(library.scanTotal)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Versione", value: appVersion)
            LabeledContent("Formati", value: "MP3, M4A/AAC, ALAC, WAV, AIFF, CAF, FLAC")
        } header: {
            Text("Info")
        } footer: {
            Text("OGG Vorbis, Opus e WMA non sono supportati da iOS: convertili in MP3 o M4A prima di trasferirli.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}
