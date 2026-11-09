import Foundation
import Network
import Combine

/// Qualità con cui ascoltare e scaricare.
enum StreamQuality: String, CaseIterable, Identifiable, Codable {
    case auto
    case high
    case saver

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:  return "Automatica"
        case .high:  return "Alta qualità"
        case .saver: return "Risparmio dati"
        }
    }

    var detail: String {
        switch self {
        case .auto:  return "Alta sotto Wi-Fi, risparmio sotto rete dati"
        case .high:  return "Il bitrate più alto disponibile"
        case .saver: return "Circa 48-70 kbps, un terzo dei dati"
        }
    }

    var symbol: String {
        switch self {
        case .auto:  return "wifi"
        case .high:  return "waveform"
        case .saver: return "arrow.down.circle.dotted"
        }
    }

    static var preferred: StreamQuality {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "streamQuality"),
                  let value = StreamQuality(rawValue: raw) else { return .auto }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "streamQuality") }
    }

    /// Risolve `auto` guardando che rete c'è adesso.
    var resolved: StreamQuality {
        guard self == .auto else { return self }
        return NetworkMonitor.shared.prefersLowData ? .saver : .high
    }
}

/// Guarda il tipo di connessione per decidere la qualità in automatico.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isWiFi = true
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sborraplay.network")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wifi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWiFi = wifi
                self.isExpensive = expensive
                self.isConstrained = constrained
                self.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    /// Vero sotto rete dati, hotspot o risparmio dati di sistema.
    var prefersLowData: Bool {
        isConstrained || isExpensive || !isWiFi
    }

    var connectionLabel: String {
        if !isOnline { return "offline" }
        if isConstrained { return "risparmio dati attivo" }
        if isWiFi { return "Wi-Fi" }
        if isExpensive { return "rete dati" }
        return "connesso"
    }
}
