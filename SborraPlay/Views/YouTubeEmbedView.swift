import SwiftUI
import WebKit
import AVFoundation

/// Player YouTube ufficiale incorporato, lo stesso meccanismo della libreria
/// youtube-ios-player-helper di Google: una WebView che ospita l'IFrame Player
/// API e un ponte verso il suo JavaScript. È la via supportata per riprodurre
/// YouTube in un'app di terze parti, e non richiede il computer acceso.
struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String
    var onState: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onState: onState) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "yt")

        let view = WKWebView(frame: .zero, configuration: config)
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        context.coordinator.webView = view

        view.loadHTMLString(Self.html(for: videoID),
                            baseURL: URL(string: "https://www.youtube.com"))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "yt")
        uiView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private let onState: (String) -> Void

        init(onState: @escaping (String) -> Void) { self.onState = onState }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let text = message.body as? String else { return }
            DispatchQueue.main.async { self.onState(text) }
        }
    }

    private static func html(for videoID: String) -> String {
        let safe = videoID.replacingOccurrences(of: "\"", with: "")
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
        <style>
          html, body { margin:0; padding:0; background:#000; height:100%; overflow:hidden; }
          #player { width:100%; height:100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
          var player;
          function tell(m) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.yt) {
              window.webkit.messageHandlers.yt.postMessage(m);
            }
          }
          function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
              height: '100%', width: '100%',
              videoId: '\(safe)',
              playerVars: {
                playsinline: 1, controls: 1, rel: 0,
                modestbranding: 1, fs: 1, origin: 'https://www.youtube.com'
              },
              events: {
                onReady: function () { tell('ready'); player.playVideo(); },
                onStateChange: function (e) { tell('state:' + e.data); },
                onError: function (e) { tell('error:' + e.data); }
              }
            });
          }
          setTimeout(function () { if (!player) tell('timeout'); }, 12000);
        </script>
        </body>
        </html>
        """
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
        if messaggio.hasPrefix("error:") {
            let codice = messaggio.replacingOccurrences(of: "error:", with: "")
            // 101, 150 e 152: incorporamento vietato dal titolare
            if ["101", "150", "152"].contains(codice) {
                if indice + 1 < coda.count {
                    stato = "questa versione non è incorporabile, ne provo un'altra…"
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        indice += 1
                        errore = nil
                    }
                } else {
                    esaurite = true
                    errore = "L'etichetta ha vietato l'incorporamento di questo brano, e non ho trovato altre versioni."
                }
                return
            }
            switch codice {
            case "100": errore = "Video non disponibile o rimosso."
            case "2":   errore = "Identificativo del video non valido."
            default:    errore = "Il player ha segnalato l'errore \(codice)."
            }
            return
        }
        switch messaggio {
        case "ready":   stato = "pronto"
        case "state:1": stato = "in riproduzione"; errore = nil; esaurite = false
        case "state:2": stato = "in pausa"
        case "state:3": stato = "sto caricando…"
        case "state:0": stato = "finito"
        case "timeout": errore = "Il player non si è caricato: controlla la connessione."
        default:        break
        }
    }
}
