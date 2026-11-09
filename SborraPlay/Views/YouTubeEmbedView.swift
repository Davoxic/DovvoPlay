import SwiftUI
import WebKit
import AVFoundation

/// Player YouTube ufficiale.
///
/// Prima costruivo una pagina HTML con dentro l'IFrame API dichiarando
/// `origin: youtube.com`: un'origine falsa, che YouTube rifiuta con
/// l'errore 152. Ora la web view naviga direttamente alla pagina di embed
/// ufficiale, quindi l'origine è autentica e non c'è niente da fingere.
struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String
    var onState: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onState: onState) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        context.coordinator.load(videoID, in: view)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onState: (String) -> Void
        private var controlli = 0

        init(onState: @escaping (String) -> Void) { self.onState = onState }

        func load(_ videoID: String, in view: WKWebView) {
            var comps = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")!
            comps.queryItems = [
                URLQueryItem(name: "playsinline", value: "1"),
                URLQueryItem(name: "autoplay", value: "1"),
                URLQueryItem(name: "rel", value: "0"),
                URLQueryItem(name: "modestbranding", value: "1")
            ]
            guard let url = comps.url else { return }
            onState("loading")
            view.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onState("loaded")
            controlli = 0
            verifica(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onState("neterror:\(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onState("neterror:\(error.localizedDescription)")
        }

        /// Il player mostra l'eventuale errore dentro la pagina: lo leggiamo
        /// invece di lasciare l'utente davanti a un rettangolo nero.
        private func verifica(_ webView: WKWebView) {
            guard controlli < 4 else { return }
            controlli += 1
            let js = """
            (function () {
              var e = document.querySelector('.ytp-error');
              if (e) { return 'blocked:' + (e.innerText || '').slice(0, 120); }
              var v = document.querySelector('video');
              if (v && !v.paused && v.currentTime > 0) { return 'playing'; }
              if (v) { return 'ready'; }
              return 'wait';
            })();
            """
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self, weak webView] in
                guard let self, let webView else { return }
                webView.evaluateJavaScript(js) { risultato, _ in
                    let esito = (risultato as? String) ?? "wait"
                    self.onState(esito)
                    if esito != "playing" && !esito.hasPrefix("blocked") {
                        self.verifica(webView)
                    }
                }
            }
        }
    }
}

/// Foglio che mostra il player. Il video resta visibile: è una condizione
/// d'uso del player incorporato, oltre che il motivo per cui funziona.
///
/// Molti video ufficiali hanno l'incorporamento disattivato dall'etichetta
/// (errori 101, 150, 152). In quel caso non ci si arrende: si passa a un'altra
/// versione dello stesso brano fra i risultati, preferendo i caricamenti
/// "Topic", che sono gli audio ufficiali generati da YouTube e quasi sempre
/// incorporabili.
struct YouTubePlayerSheet: View {
    let track: OnlineTrack
    @ObservedObject var online: OnlineStore

    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State var indice = 0
    @State var stato = "carico il player…"
    @State var errore: String?
    @State var esaurite = false

    private var coda: [OnlineTrack] {
        var out = [track]
        let tutte = online.embedAlternatives + online.results.filter { $0.source == .youtube }
        var viste = Set([track.id])
        for candidato in YouTubePlayerSheet.ordina(tutte, come: track)
        where viste.insert(candidato.id).inserted {
            out.append(candidato)
        }
        return out
    }

    private var corrente: OnlineTrack {
        coda.indices.contains(indice) ? coda[indice] : track
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let videoID = corrente.resolveHint {
                    YouTubeEmbedView(videoID: videoID) { messaggio in
                        aggiorna(messaggio)
                    }
                    .id(videoID)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                } else {
                    Color.black.aspectRatio(16.0/9.0, contentMode: .fit)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(corrente.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(corrente.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let errore {
                        Label(errore, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        HStack(spacing: 6) {
                            Text(stato)
                            if coda.count > 1 {
                                Text("· versione \(indice + 1) di \(coda.count)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if esaurite || errore != nil {
                        HStack(spacing: 10) {
                            if indice + 1 < coda.count {
                                Button {
                                    passaAllaProssima()
                                } label: {
                                    Label("Prova un'altra versione", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.footnote.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                            }
                            if let pagina = corrente.pageURL {
                                Button {
                                    openURL(pagina)
                                } label: {
                                    Label("Apri su YouTube", systemImage: "arrow.up.forward.app")
                                        .font(.footnote.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top, 2)
                    }

                    Divider().padding(.vertical, 4)

                    Label("Il player ufficiale deve restare in vista: a schermo bloccato l'audio si ferma. Per ascoltare in background scarica il brano, o accendi il ponte sul computer.",
                          systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Spacer()
            }
            .navigationTitle("YouTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .onAppear {
            PlayerEngine.shared.pause()
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    private func passaAllaProssima() {
        guard indice + 1 < coda.count else {
            esaurite = true
            errore = "Nessuna versione di questo brano è incorporabile. Puoi aprirlo su YouTube, o scaricarlo col ponte sul computer."
            return
        }
        indice += 1
        errore = nil
        esaurite = false
        stato = "provo un'altra versione…"
    }

    /// Mette davanti le versioni che hanno più probabilità di essere
    /// incorporabili e di essere lo stesso brano.
    static func ordina(_ candidati: [OnlineTrack], come riferimento: OnlineTrack) -> [OnlineTrack] {
        let titolo = normalizza(riferimento.title)
        let artista = normalizza(riferimento.artist)

        func punteggio(_ t: OnlineTrack) -> Int {
            var p = 0
            let canale = normalizza(t.artist)
            let nome = normalizza(t.title)
            if canale.hasSuffix("topic") { p += 50 }
            if nome.contains("official audio") || nome.contains("audio") { p += 12 }
            if nome.contains("lyric") { p += 8 }
            if !artista.isEmpty, canale.contains(artista) || nome.contains(artista) { p += 15 }
            if !titolo.isEmpty, nome.contains(titolo) || titolo.contains(nome) { p += 25 }
            if riferimento.duration > 0, t.duration > 0 {
                let scarto = abs(t.duration - riferimento.duration)
                if scarto <= 3 { p += 30 } else if scarto <= 10 { p += 15 } else if scarto > 60 { p -= 30 }
            }
            for parola in ["live", "cover", "remix", "reaction", "karaoke", "sped up", "slowed"]
            where nome.contains(parola) && !titolo.contains(parola) {
                p -= 25
            }
            return p
        }

        return candidati
            .map { ($0, punteggio($0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private static func normalizza(_ testo: String) -> String {
        testo.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func aggiorna(_ messaggio: String) {
        if messaggio.hasPrefix("blocked") {
            let motivo = messaggio
                .replacingOccurrences(of: "blocked:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if indice + 1 < coda.count {
                stato = "questa versione non parte, ne provo un'altra…"
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    indice += 1
                    errore = nil
                }
            } else {
                esaurite = true
                errore = motivo.isEmpty
                    ? "Nessuna versione di questo brano parte nel player."
                    : motivo
            }
            return
        }
        if messaggio.hasPrefix("neterror:") {
            errore = "Connessione: " + messaggio.replacingOccurrences(of: "neterror:", with: "")
            return
        }
        switch messaggio {
        case "loading": stato = "carico il player…"
        case "loaded":  stato = "player caricato"
        case "ready":   stato = "pronto, premi play se non parte da solo"
        case "playing": stato = "in riproduzione"; errore = nil; esaurite = false
        case "wait":    stato = "sto caricando…"
        default:        break
        }
    }
}
