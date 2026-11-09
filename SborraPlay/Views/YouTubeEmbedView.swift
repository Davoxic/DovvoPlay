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
struct YouTubePlayerSheet: View {
    let track: OnlineTrack
    @Environment(\.dismiss) var dismiss
    @State var stato = "carico il player…"
    @State var errore: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let videoID = track.resolveHint {
                    YouTubeEmbedView(videoID: videoID) { messaggio in
                        aggiorna(messaggio)
                    }
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                } else {
                    Color.black.aspectRatio(16.0/9.0, contentMode: .fit)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let errore {
                        Label(errore, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text(stato)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider().padding(.vertical, 4)

                    Label("Il player ufficiale di YouTube deve restare in vista: se chiudi o blocchi lo schermo, l'audio si ferma. Per ascoltare a schermo spento scarica il brano, o accendi il ponte sul computer.",
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
            // niente due audio sovrapposti
            PlayerEngine.shared.pause()
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    private func aggiorna(_ messaggio: String) {
        if messaggio.hasPrefix("error:") {
            let codice = messaggio.replacingOccurrences(of: "error:", with: "")
            switch codice {
            case "101", "150":
                errore = "Questo video non è incorporabile: l'autore ne ha vietato la riproduzione fuori da YouTube."
            case "100":
                errore = "Video non disponibile o rimosso."
            case "2":
                errore = "Identificativo del video non valido."
            default:
                errore = "Il player ha segnalato l'errore \(codice)."
            }
            return
        }
        switch messaggio {
        case "ready":   stato = "pronto"
        case "state:1": stato = "in riproduzione"; errore = nil
        case "state:2": stato = "in pausa"
        case "state:3": stato = "sto caricando…"
        case "state:0": stato = "finito"
        case "timeout": errore = "Il player non si è caricato: controlla la connessione."
        default:        break
        }
    }
}
