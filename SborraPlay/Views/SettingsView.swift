import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var library: LibraryStore
    @ObservedObject var server = LocalServer.shared
    @AppStorage("serverAutoStart") var autoStart = false
    @AppStorage("autoBackup") var autoBackup = true
    @AppStorage("streamQuality") var qualityRaw = StreamQuality.auto.rawValue
    @AppStorage("pipedInstance") var pipedInstance = ""
    @ObservedObject var network = NetworkMonitor.shared
    @State var instanceCheck: String?
    @State var exporting: ExportedFile?
    @State var showBackupImporter = false
    @State var pendingBackup: Data?
    @State var askRestoreMode = false
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
                streamingSection
                bridgeSection
                backupSection
                librarySection
                storageSection
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
            .sheet(item: $exporting) { item in
                ShareSheet(items: [item.url])
            }
            .confirmationDialog("Come vuoi ripristinare?",
                                isPresented: $askRestoreMode,
                                titleVisibility: .visible) {
                Button("Unisci alle playlist attuali") {
                    if let data = pendingBackup { library.importBackup(data: data, replace: false) }
                    pendingBackup = nil
                }
                Button("Sostituisci tutto", role: .destructive) {
                    if let data = pendingBackup { library.importBackup(data: data, replace: true) }
                    pendingBackup = nil
                }
                Button("Annulla", role: .cancel) { pendingBackup = nil }
            }
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

    private var backupSection: some View {
        Section {
            Button {
                if let url = library.exportBackup() { exporting = ExportedFile(url: url) }
            } label: {
                Label("Esporta backup…", systemImage: "square.and.arrow.up")
            }

            Button {
                showBackupImporter = true
            } label: {
                Label("Importa backup…", systemImage: "square.and.arrow.down")
            }

            Toggle(isOn: $autoBackup) {
                Label("Copia automatica giornaliera", systemImage: "clock.arrow.circlepath")
            }

            NavigationLink {
                BackupsListView().environmentObject(library)
            } label: {
                HStack {
                    Label("Copie automatiche", systemImage: "folder.badge.gearshape")
                    Spacer()
                    Text("\(BackupManager.listBackups().count)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Il backup contiene playlist, copertine, ordinamento e impostazioni, più l'elenco dei brani per sapere cosa manca dopo un ripristino. I file audio non ci stanno dentro: quelli restano in Documents/Music e li vedi dall'app File. Esporta il backup su iCloud o sul PC prima di disinstallare l'app.")
        }
        .fileImporter(isPresented: $showBackupImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingBackup = data
                    askRestoreMode = true
                } else {
                    library.lastMessage = "Non riesco a leggere quel file"
                }
            case .failure(let error):
                library.lastMessage = error.localizedDescription
            }
        }
    }

    private var streamingSection: some View {
        Section {
            Picker(selection: $qualityRaw) {
                ForEach(StreamQuality.allCases) { q in
                    Text(q.label).tag(q.rawValue)
                }
            } label: {
                Label("Qualità", systemImage: "dial.high")
            }
            .onChange(of: qualityRaw) { _ in PipedClient.resetInstanceCache() }

            if let q = StreamQuality(rawValue: qualityRaw) {
                Text(q.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Connessione", value: network.connectionLabel)

            HStack {
                Label("Istanza Piped", systemImage: "server.rack")
                Spacer()
                TextField(PipedClient.activeInstance, text: $pipedInstance)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote)
                    .onChange(of: pipedInstance) { _ in
                        PipedClient.resetInstanceCache()
                        instanceCheck = nil
                    }
            }

            Button {
                let target = pipedInstance.isEmpty ? PipedClient.activeInstance : pipedInstance
                instanceCheck = "provo…"
                Task {
                    let ok = await PipedClient.test(target)
                    await MainActor.run { instanceCheck = ok ? "funziona" : "non risponde" }
                }
            } label: {
                HStack {
                    Label("Prova l'istanza", systemImage: "bolt.horizontal")
                    if let instanceCheck {
                        Spacer()
                        Text(instanceCheck).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Ricerca e streaming")
        } footer: {
            Text("YouTube passa dalle istanze pubbliche Piped: nessun computer acceso, nessuna configurazione. Se una istanza è lenta o giù, l'app ne prova un'altra da sola; qui puoi forzarne una tua. SoundCloud invece parla direttamente col suo server. In risparmio dati gli stream scendono a 48-70 kbps.")
        }
    }

    private var bridgeSection: some View {
        Section {
            if let bridge = UserDefaults.standard.string(forKey: "bridgeURL"), !bridge.isEmpty {
                LabeledContent("Computer", value: bridge)
                Button(role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "bridgeURL")
                    library.lastMessage = "Computer scollegato"
                } label: {
                    Label("Scollega il computer", systemImage: "xmark.circle")
                }
            } else {
                Label("Nessun computer collegato", systemImage: "desktopcomputer")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Ponte sul computer (riserva)")
        } footer: {
            Text("Serve solo se le istanze Piped sono tutte irraggiungibili: in quel caso la ricerca YouTube ripiega su yt-dlp che gira sul PC. Sul computer apri SborraPlay e scegli \"Avvia il ponte\": si annuncia da solo.")
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

    private var storageSection: some View {
        Section {
            LabeledContent("Musica", value: "Documents/Music")
            LabeledContent("Playlist", value: "playlists.json")
            LabeledContent("Copertine", value: "Documents/Covers")
        } header: {
            Text("Dove stanno i tuoi file")
        } footer: {
            Text("I brani che importi vengono copiati dentro l'app, non letti dal percorso d'origine: puoi cancellare gli originali sul computer. Reinstallando sopra la stessa app (per rinnovare la firma) non perdi niente; disinstallandola invece sparisce tutto, quindi tieni un backup esportato.")
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
