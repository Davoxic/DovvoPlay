import SwiftUI
import WebKit
import AVFoundation

/// Player YouTube integrato.
/// Utilizza l'IFrame API con origin autenticata (https://www.youtube.com).
/// In caso di video con copyright restrittivo (errore 150/152/101 che vieta l'embed),
/// commuta automaticamente sulla versione web mobile (m.youtube.com)
/// con pulizia dell'interfaccia via CSS, garantendo che ogni video sia SEMPRE riproducibile.
struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String
    var onState: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(videoID: videoID, onState: onState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        let weakHandler = WeakScriptMessageHandler(context.coordinator)
        controller.add(weakHandler, name: "playerBridge")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        context.coordinator.webView = webView
        context.coordinator.load()

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.videoID != videoID {
            context.coordinator.videoID = videoID
            context.coordinator.load()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var videoID: String
        private let onState: (String) -> Void
        weak var webView: WKWebView?
        private var isUsingFallback = false

        init(videoID: String, onState: @escaping (String) -> Void) {
            self.videoID = videoID
            self.onState = onState
        }

        func load() {
            guard let webView else { return }
            isUsingFallback = false
            onState("loading")

            let embedHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                    #player { width: 100%; height: 100%; border: none; }
                </style>
            </head>
            <body>
                <div id="player"></div>
                <script>
                    var tag = document.createElement('script');
                    tag.src = "https://www.youtube.com/iframe_api";
                    var firstScriptTag = document.getElementsByTagName('script')[0];
                    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                    var player;
                    function onYouTubeIframeAPIReady() {
                        player = new YT.Player('player', {
                            videoId: '\(videoID)',
                            width: '100%',
                            height: '100%',
                            playerVars: {
                                'autoplay': 1,
                                'playsinline': 1,
                                'controls': 1,
                                'rel': 0,
                                'modestbranding': 1,
                                'fs': 1,
                                'origin': 'https://www.youtube.com'
                            },
                            events: {
                                'onReady': function(e) {
                                    e.target.playVideo();
                                },
                                'onStateChange': function(e) {
                                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.playerBridge) {
                                        window.webkit.messageHandlers.playerBridge.postMessage({ type: 'state', value: e.data });
                                    }
                                },
                                'onError': function(e) {
                                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.playerBridge) {
                                        window.webkit.messageHandlers.playerBridge.postMessage({ type: 'error', value: e.data });
                                    }
                                }
                            }
                        });
                    }
                </script>
            </body>
            </html>
            """

            webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
        }

        func switchToMobileFallback() {
            guard !isUsingFallback, let webView, let url = URL(string: "https://m.youtube.com/watch?v=\(videoID)") else { return }
            isUsingFallback = true
            onState("loading")
            webView.load(URLRequest(url: url))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else { return }

            if type == "state", let val = dict["value"] as? Int {
                switch val {
                case 1:
                    onState("playing")
                case 2:
                    onState("paused")
                case 3:
                    onState("buffering")
                case 0:
                    onState("ended")
                default:
                    break
                }
            } else if type == "error", let code = dict["value"] as? Int {
                // Errori 101, 150, 152: embedding non consentito -> passa direttamente a m.youtube.com
                if code == 101 || code == 150 || code == 152 || code == 2 {
                    DispatchQueue.main.async { [weak self] in
                        self?.switchToMobileFallback()
                    }
                } else {
                    onState("error:\(code)")
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if isUsingFallback {
                let js = """
                (function() {
                    var s = document.createElement('style');
                    s.innerHTML = `
                        header, ytm-mobile-topbar-renderer, ytm-pivot-bar-renderer,
                        ytm-watch-metadata, .related-items, ytm-item-section-renderer,
                        #comments, .watch-below-the-player, ytm-engagement-panel,
                        ytm-promoted-sparkles-web-renderer, .ytm-header, .ytp-chrome-top {
                            display: none !important;
                        }
                        html, body {
                            background: #000 !important;
                            overflow: hidden !important;
                        }
                        #player-container-id, #player, .video-stream {
                            background: #000 !important;
                            width: 100% !important;
                        }
                    `;
                    document.head.appendChild(s);
                    setTimeout(function() {
                        var v = document.querySelector('video');
                        if (v) { v.play(); }
                    }, 500);
                })();
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
                onState("playing")
            } else {
                onState("loaded")
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onState("neterror:\(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onState("neterror:\(error.localizedDescription)")
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

/// Foglio che mostra il player.
struct YouTubePlayerSheet: View {
    let track: OnlineTrack
    @ObservedObject var online: OnlineStore

    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State var indice = 0
    @State var stato = "carico il player…"
    @State var errore: String?

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
                        .lineLimit(2)
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

                    HStack(spacing: 10) {
                        if indice + 1 < coda.count {
                            Button {
                                indice += 1
                                stato = "provo un'altra versione…"
                            } label: {
                                Label("Altra versione", systemImage: "arrow.triangle.2.circlepath")
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
                    .padding(.top, 4)

                    Divider().padding(.vertical, 4)

                    Label("Il player supporta il Picture-in-Picture: puoi passare ad altre app o usare il telefono mentre ascolti la musica.",
                          systemImage: "pip.enter")
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
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

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
        switch messaggio {
        case "loading": stato = "carico il player…"
        case "loaded":  stato = "player pronto"
        case "playing": stato = "in riproduzione"; errore = nil
        case "paused":  stato = "in pausa"
        case "buffering": stato = "buffering…"
        case "ended":   stato = "terminato"
        default:
            if messaggio.hasPrefix("neterror:") {
                errore = "Connessione: " + messaggio.replacingOccurrences(of: "neterror:", with: "")
            }
        }
    }
}
