import Foundation
import AVFoundation

struct RawMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var artwork: Data?
    var duration: Double = 0
}

enum MetadataReader {

    static func read(url: URL) async -> RawMetadata {
        var meta = RawMetadata()
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])

        if let d = try? await asset.load(.duration) {
            let secs = CMTimeGetSeconds(d)
            if secs.isFinite && secs > 0 { meta.duration = secs }
        }

        var items: [AVMetadataItem] = []
        if let common = try? await asset.load(.commonMetadata) { items.append(contentsOf: common) }
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                if let fitems = try? await asset.loadMetadata(for: format) {
                    items.append(contentsOf: fitems)
                }
            }
        }

        for item in items {
            switch canonicalKey(item) {
            case "title":
                if meta.title == nil { meta.title = await string(item) }
            case "artist":
                if meta.artist == nil { meta.artist = await string(item) }
            case "album":
                if meta.album == nil { meta.album = await string(item) }
            case "albumArtist":
                if meta.albumArtist == nil { meta.albumArtist = await string(item) }
            case "genre":
                if meta.genre == nil { meta.genre = await string(item) }
            case "year":
                if meta.year == nil { meta.year = await year(item) }
            case "track":
                if meta.trackNumber == nil { meta.trackNumber = await number(item) }
            case "disc":
                if meta.discNumber == nil { meta.discNumber = await number(item) }
            case "artwork":
                if meta.artwork == nil {
                    if let data = try? await item.load(.dataValue), let data, data.count > 100 {
                        meta.artwork = data
                    }
                }
            default:
                break
            }
        }

        // Se mancano titolo/artista li deduciamo dal nome file "Artista - Titolo.mp3".
        let base = url.deletingPathExtension().lastPathComponent
        if meta.title == nil || meta.title?.isEmpty == true {
            if let dash = base.range(of: " - "), meta.artist == nil {
                meta.artist = String(base[base.startIndex..<dash.lowerBound])
                meta.title = String(base[dash.upperBound...])
            } else {
                meta.title = base
            }
        }
        return meta
    }

    // MARK: - helper

    private static func string(_ item: AVMetadataItem) async -> String? {
        if let s = try? await item.load(.stringValue), let s {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let n = try? await item.load(.numberValue), let n { return n.stringValue }
        return nil
    }

    private static func number(_ item: AVMetadataItem) async -> Int? {
        if let n = try? await item.load(.numberValue), let n { return n.intValue }
        if let s = await string(item) {
            let first = s.split(separator: "/").first.map(String.init) ?? s
            let digits = first.filter { $0.isNumber }
            return Int(digits)
        }
        if let d = try? await item.load(.dataValue), let d, d.count >= 4 {
            // iTunes "trkn": 8 byte, il numero è nei byte 2-3
            let bytes = [UInt8](d)
            if bytes.count >= 4 { return Int(bytes[2]) << 8 | Int(bytes[3]) }
        }
        return nil
    }

    private static func year(_ item: AVMetadataItem) async -> Int? {
        if let date = try? await item.load(.dateValue), let date {
            return Calendar.current.component(.year, from: date)
        }
        if let s = await string(item) {
            let digits = s.prefix(while: { $0.isNumber })
            if digits.count == 4, let y = Int(digits) { return y }
            if let range = s.range(of: #"\d{4}"#, options: .regularExpression) { return Int(s[range]) }
        }
        if let n = try? await item.load(.numberValue), let n { return n.intValue }
        return nil
    }

    private static func canonicalKey(_ item: AVMetadataItem) -> String {
        if let common = item.commonKey?.rawValue {
            switch common {
            case "title": return "title"
            case "artist": return "artist"
            case "albumName": return "album"
            case "artwork": return "artwork"
            case "creationDate": return "year"
            case "type": return "genre"
            default: break
            }
        }
        let ident = (item.identifier?.rawValue ?? "").uppercased()
        if ident.isEmpty { return "" }
        if ident.hasSuffix("TRCK") || ident.hasSuffix("TRKN") { return "track" }
        if ident.hasSuffix("TPOS") || ident.hasSuffix("DISK") { return "disc" }
        if ident.hasSuffix("TPE2") || ident.hasSuffix("AART") || ident.hasSuffix("ALBUMARTIST") { return "albumArtist" }
        if ident.hasSuffix("TCON") || ident.hasSuffix("GNRE") || ident.hasSuffix("GEN") { return "genre" }
        if ident.hasSuffix("TYER") || ident.hasSuffix("TDRC") || ident.hasSuffix("TDRL") || ident.hasSuffix("DAY") { return "year" }
        if ident.hasSuffix("TIT2") { return "title" }
        if ident.hasSuffix("TPE1") { return "artist" }
        if ident.hasSuffix("TALB") { return "album" }
        if ident.hasSuffix("APIC") || ident.hasSuffix("COVR") { return "artwork" }
        return ""
    }
}
