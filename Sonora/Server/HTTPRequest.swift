import Foundation

struct HTTPRequest {
    var method: String = "GET"
    var rawTarget: String = "/"
    var path: String = "/"
    var query: [String: String] = [:]
    var headers: [String: String] = [:]

    var contentLength: Int { Int(headers["content-length"] ?? "") ?? 0 }
    var expectsContinue: Bool {
        (headers["expect"] ?? "").lowercased().contains("100-continue")
    }

    static func parse(head: String) -> HTTPRequest? {
        var lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        lines.removeFirst()
        let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        var req = HTTPRequest()
        req.method = parts[0].uppercased()
        req.rawTarget = String(parts[1])

        let split = req.rawTarget.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        req.path = String(split.first ?? "/").removingPercentEncoding ?? String(split.first ?? "/")
        if split.count > 1 {
            for pair in split[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let k = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let v = kv.count > 1 ? (String(kv[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? "") : ""
                req.query[k] = v
            }
        }
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            req.headers[key] = value
        }
        return req
    }
}

struct HTTPResponse {
    var status: Int = 200
    var contentType: String = "text/plain; charset=utf-8"
    var body: Data = Data()
    var extraHeaders: [String: String] = [:]

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return HTTPResponse(status: status, contentType: "application/json; charset=utf-8", body: data)
    }

    static func text(_ string: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/plain; charset=utf-8", body: Data(string.utf8))
    }

    static func html(_ string: String) -> HTTPResponse {
        HTTPResponse(status: 200, contentType: "text/html; charset=utf-8", body: Data(string.utf8))
    }

    var statusText: String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        case 415: return "Unsupported Media Type"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }

    func serialized() -> Data {
        var head = "HTTP/1.1 \(status) \(statusText)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n"
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Access-Control-Allow-Methods: GET, PUT, POST, DELETE, OPTIONS\r\n"
        head += "Access-Control-Allow-Headers: *\r\n"
        head += "Cache-Control: no-store\r\n"
        for (k, v) in extraHeaders { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}
