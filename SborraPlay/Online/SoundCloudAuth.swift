import Foundation
import Combine

/// Tiene il token del tuo account SoundCloud. Sta nel portachiavi, non nelle
/// preferenze: è una credenziale.
@MainActor
final class SoundCloudAuth: ObservableObject {

    static let shared = SoundCloudAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var username: String?
    @Published private(set) var isGoPlus = false

    private init() {
        isLoggedIn = SoundCloudCredentials.token != nil
        username = UserDefaults.standard.string(forKey: "scUsername")
        isGoPlus = UserDefaults.standard.bool(forKey: "scGoPlus")
    }

    var token: String? { SoundCloudCredentials.token }

    func signIn(with token: String) async {
        guard !token.isEmpty else { return }
        SoundCloudCredentials.token = token
        isLoggedIn = true
        await refreshProfile()
    }

    func signOut() {
        SoundCloudCredentials.token = nil
        UserDefaults.standard.removeObject(forKey: "scUsername")
        UserDefaults.standard.removeObject(forKey: "scGoPlus")
        isLoggedIn = false
        username = nil
        isGoPlus = false
    }

    /// Chiede a SoundCloud chi siamo: conferma che il token è valido.
    func refreshProfile() async {
        guard let token = SoundCloudCredentials.token else { return }
        guard let id = try? await SoundCloudClient.clientID() else { return }
        var comps = URLComponents(string: "https://api-v2.soundcloud.com/me")!
        comps.queryItems = [URLQueryItem(name: "client_id", value: id)]
        guard let url = comps.url else { return }

        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return }

        if http.statusCode == 401 || http.statusCode == 403 {
            signOut()
            return
        }
        guard http.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let name = (root["username"] as? String) ?? (root["full_name"] as? String)
        let consumerPlan = (root["consumer_subscriptions"] as? [[String: Any]])?.first
        let planName = ((consumerPlan?["product"] as? [String: Any])?["id"] as? String) ?? ""

        username = name
        isGoPlus = planName.contains("go") || planName.contains("pro")
        UserDefaults.standard.set(name, forKey: "scUsername")
        UserDefaults.standard.set(isGoPlus, forKey: "scGoPlus")
        isLoggedIn = true
    }
}

/// Il token, raggiungibile da qualunque contesto: il client HTTP non gira
/// sul main actor.
enum SoundCloudCredentials {
    private static let service = "com.dchietti.sborraplay.soundcloud"
    private static let account = "oauth_token"

    static var token: String? {
        get { Keychain.read(service: service, account: account) }
        set {
            if let newValue, !newValue.isEmpty {
                Keychain.write(newValue, service: service, account: account)
            } else {
                Keychain.delete(service: service, account: account)
            }
        }
    }

    static var header: [String: String] {
        guard let token else { return [:] }
        return ["Authorization": "OAuth \(token)"]
    }
}

/// Accesso minimo al portachiavi, quanto basta per un token.
enum Keychain {
    static func write(_ value: String, service: String, account: String) {
        delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
