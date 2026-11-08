import SwiftUI

/// Elenco delle copie automatiche salvate in Documents/Backups.
struct BackupsListView: View {
    @EnvironmentObject var library: LibraryStore
    @State var files: [URL] = []
    @State var sharing: ExportedFile?
    @State var restoring: URL?
    @State var askReplace = false

    var body: some View {
        List {
            if files.isEmpty {
                Text("Nessuna copia automatica ancora. Ne viene creata una al giorno, se hai almeno una playlist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(files, id: \.self) { url in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label(for: url)).font(.body)
                    Text(detail(for: url)).font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        try? FileManager.default.removeItem(at: url)
                        reload()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                    Button {
                        sharing = ExportedFile(url: url)
                    } label: {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
                .onTapGesture {
                    restoring = url
                    askReplace = true
                }
            }
        }
        .navigationTitle("Copie automatiche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Crea ora") {
                    _ = BackupManager.autoBackup(library.makeBackup())
                    UserDefaults.standard.set(Date(), forKey: "lastAutoBackup")
                    reload()
                }
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $sharing) { item in
            ShareSheet(items: [item.url])
        }
        .confirmationDialog("Ripristinare questa copia?",
                            isPresented: $askReplace,
                            titleVisibility: .visible) {
            Button("Unisci alle playlist attuali") {
                if let url = restoring { library.restoreFromFile(at: url, replace: false) }
                restoring = nil
            }
            Button("Sostituisci tutto", role: .destructive) {
                if let url = restoring { library.restoreFromFile(at: url, replace: true) }
                restoring = nil
            }
            Button("Annulla", role: .cancel) { restoring = nil }
        }
    }

    private func reload() {
        files = BackupManager.listBackups()
    }

    private func label(for url: URL) -> String {
        let name = url.lastPathComponent
            .replacingOccurrences(of: "SborraPlay-", with: "")
            .replacingOccurrences(of: ".sborraplay.json", with: "")
        return name
    }

    private func detail(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
        guard let date = values?.contentModificationDate else { return size }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(f.string(from: date)) · \(size)"
    }
}
