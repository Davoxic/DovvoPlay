import SwiftUI
import WebKit

/// Pagina di accesso ufficiale di SoundCloud dentro l'app. Niente password
/// passa da qui: al termine leggiamo soltanto il cookie di sessione che il
/// sito stesso rilascia al tuo browser, e lo teniamo nel portachiavi.
struct SoundCloudLoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var auth = SoundCloudAuth.shared
    @State var status = "Accedi con il tuo account SoundCloud"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)

                SoundCloudWebView { token in
                    status = "Connesso, controllo il profilo…"
                    Task {
                        await auth.signIn(with: token)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Accedi a SoundCloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}

struct SoundCloudWebView: UIViewRepresentable {
    var onToken: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onToken: onToken) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        if let url = URL(string: "https://soundcloud.com/signin") {
            view.load(URLRequest(url: url))
        }
        context.coordinator.start(view)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onToken: (String) -> Void
        private var timer: Timer?
        private var done = false

        init(onToken: @escaping (String) -> Void) {
            self.onToken = onToken
        }

        deinit { timer?.invalidate() }

        func start(_ view: WKWebView) {
            // il cookie compare dopo il login, anche senza cambio pagina
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self, weak view] _ in
                guard let self, let view, !self.done else { return }
                view.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    guard let cookie = cookies.first(where: { $0.name == "oauth_token" }),
                          !cookie.value.isEmpty else { return }
                    self.done = true
                    self.timer?.invalidate()
                    self.onToken(cookie.value)
                }
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !done else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.done,
                      let cookie = cookies.first(where: { $0.name == "oauth_token" }),
                      !cookie.value.isEmpty else { return }
                self.done = true
                self.timer?.invalidate()
                self.onToken(cookie.value)
            }
        }
    }
}
