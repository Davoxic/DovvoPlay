import Foundation
import Darwin

enum NetworkInfo {
    /// Indirizzi IPv4 delle interfacce Wi-Fi / hotspot attive.
    static func localAddresses() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return result }
        defer { freeifaddrs(ifaddr) }

        var pointer = ifaddr
        while let ptr = pointer {
            defer { pointer = ptr.pointee.ifa_next }
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP,
                  (flags & IFF_RUNNING) == IFF_RUNNING,
                  (flags & IFF_LOOPBACK) == 0,
                  let addr = ptr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("ap") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let res = getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                  &host, socklen_t(host.count),
                                  nil, 0, NI_NUMERICHOST)
            if res == 0 {
                let ip = String(cString: host)
                if !ip.isEmpty, !result.contains(ip) { result.append(ip) }
            }
        }
        return result
    }
}
