import Foundation
import AVFoundation
import UIKit

public struct AudioMetadata {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let coverPath: String?
    public let duration: TimeInterval?
    public let bpm: Double?

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        coverPath: String? = nil,
        duration: TimeInterval? = nil,
        bpm: Double? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.coverPath = coverPath
        self.duration = duration
        self.bpm = bpm
    }
}

public class MetadataService {
    public static let shared = MetadataService()
    private init() {}

    public func extractMetadata(fileURL: URL, coversDirectory: URL) async -> AudioMetadata {
        let asset = AVURLAsset(url: fileURL)

        var title: String?
        var artist: String?
        var album: String?
        var coverPath: String?
        var duration: TimeInterval?
        var bpm: Double?

        // 1. Duration
        do {
            let durationValue = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(durationValue)
            if !seconds.isNaN && !seconds.isInfinite && seconds > 0 {
                duration = seconds
            }
        } catch {
            let cmTime = asset.duration
            let seconds = CMTimeGetSeconds(cmTime)
            if !seconds.isNaN && !seconds.isInfinite && seconds > 0 {
                duration = seconds
            }
        }

        // 2. Common Metadata (Title, Artist, Album, Artwork)
        do {
            let commonItems = try await asset.load(.commonMetadata)
            for item in commonItems {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        title = stringVal.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyArtist:
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        artist = stringVal.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyAlbumName:
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        album = stringVal.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .commonKeyArtwork:
                    if let dataVal = try? await item.load(.dataValue), !dataVal.isEmpty {
                        coverPath = saveArtworkData(dataVal, for: fileURL, in: coversDirectory)
                    }
                default:
                    break
                }
            }
        } catch {
            // Fallback for older iOS versions
            for item in asset.commonMetadata {
                guard let key = item.commonKey else { continue }
                if key == .commonKeyTitle, let str = item.stringValue, !str.isEmpty {
                    title = str.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if key == .commonKeyArtist, let str = item.stringValue, !str.isEmpty {
                    artist = str.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if key == .commonKeyAlbumName, let str = item.stringValue, !str.isEmpty {
                    album = str.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if key == .commonKeyArtwork, let data = item.dataValue, !data.isEmpty {
                    coverPath = saveArtworkData(data, for: fileURL, in: coversDirectory)
                }
            }
        }

        // 3. ID3 / QuickTime format-specific metadata (including TBPM frame)
        do {
            let metadataFormats = try await asset.load(.availableMetadataFormats)
            for format in metadataFormats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    let keyStr = item.identifier?.rawValue.lowercased() ?? ""
                    let stringKey = (item.key as? String)?.lowercased() ?? ""

                    // Check for BPM (TBPM or tmpo)
                    if keyStr.contains("tbpm") || keyStr.contains("tmpo") || stringKey.contains("tbpm") || stringKey.contains("bpm") {
                        if let str = try? await item.load(.stringValue),
                           let val = Double(str.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) {
                            bpm = val
                        } else if let num = try? await item.load(.numberValue) {
                            bpm = num.doubleValue
                        }
                    }

                    // Fallback artwork from format metadata if not already found
                    if coverPath == nil && (keyStr.contains("apic") || keyStr.contains("covr") || stringKey == "apic" || stringKey == "covr") {
                        if let dataVal = try? await item.load(.dataValue), !dataVal.isEmpty {
                            coverPath = saveArtworkData(dataVal, for: fileURL, in: coversDirectory)
                        }
                    }
                }
            }
        } catch {}

        // 4. Filename splitting fallback: "Artist - Title"
        let filename = fileURL.deletingPathExtension().lastPathComponent
        if (title == nil || title!.isEmpty) || (artist == nil || artist!.isEmpty) {
            if filename.contains(" - ") {
                let parts = filename.components(separatedBy: " - ")
                if artist == nil || artist!.isEmpty {
                    artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if title == nil || title!.isEmpty {
                    title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                if title == nil || title!.isEmpty {
                    title = filename
                }
                if artist == nil || artist!.isEmpty {
                    artist = "Artista sconosciuto"
                }
            }
        }

        return AudioMetadata(
            title: title,
            artist: artist,
            album: album ?? "",
            coverPath: coverPath,
            duration: duration,
            bpm: bpm
        )
    }

    private func saveArtworkData(_ data: Data, for fileURL: URL, in directory: URL) -> String? {
        let hash = abs(fileURL.path.hashValue)
        let isPng = data.count > 8 && data[0] == 0x89 && data[1] == 0x50
        let ext = isPng ? "png" : "jpg"
        let coverURL = directory.appendingPathComponent("cover_\(hash).\(ext)")

        if FileManager.default.fileExists(atPath: coverURL.path) {
            return coverURL.path
        }

        do {
            try data.write(to: coverURL, options: .atomic)
            return coverURL.path
        } catch {
            return nil
        }
    }
}
