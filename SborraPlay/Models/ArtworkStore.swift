import Foundation
import UIKit
import CryptoKit

/// Salva e rilegge le copertine su disco (cache), deduplicandole per album.
enum ArtworkStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func key(forAlbumArtist artist: String, album: String) -> String {
        let raw = "\(artist.lowercased())|\(album.lowercased())"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(24).description
    }

    static func url(for id: String) -> URL {
        LibraryPaths.artworkDirectory.appendingPathComponent("\(id).jpg")
    }

    static func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    /// Salva i byte di una copertina ridimensionandola a max 600px.
    @discardableResult
    static func store(data: Data, id: String) -> Bool {
        LibraryPaths.ensureDirectories()
        guard let image = UIImage(data: data) else { return false }
        let resized = resize(image, maxSide: 600)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return false }
        do {
            try jpeg.write(to: url(for: id), options: .atomic)
            cache.setObject(resized, forKey: id as NSString)
            return true
        } catch {
            return false
        }
    }

    static func image(for id: String?) -> UIImage? {
        guard let id, !id.isEmpty else { return nil }
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let data = try? Data(contentsOf: url(for: id)), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: id as NSString)
        return img
    }

    static func image(for track: Track?) -> UIImage? {
        image(for: track?.artworkID)
    }

    private static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0, max(w, h) > maxSide else { return image }
        let scale = maxSide / max(w, h)
        let size = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

/// Copertine delle playlist scelte dal rullino. Stanno in Documents (non in cache):
/// devono sopravvivere alla pulizia del sistema.
enum CoverStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func url(for id: String) -> URL {
        LibraryPaths.coversDirectory.appendingPathComponent("\(id).jpg")
    }

    /// Salva l'immagine scelta, ritagliata quadrata e ridotta a 1000px.
    static func store(data: Data, for playlistID: UUID) -> String? {
        LibraryPaths.ensureDirectories()
        guard let image = UIImage(data: data) else { return nil }
        let square = squareCrop(image, side: 1000)
        guard let jpeg = square.jpegData(compressionQuality: 0.88) else { return nil }
        let id = playlistID.uuidString
        do {
            try jpeg.write(to: url(for: id), options: .atomic)
            cache.setObject(square, forKey: id as NSString)
            return id
        } catch {
            return nil
        }
    }

    static func image(for id: String?) -> UIImage? {
        guard let id, !id.isEmpty else { return nil }
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let data = try? Data(contentsOf: url(for: id)),
              let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: id as NSString)
        return img
    }

    static func remove(id: String?) {
        guard let id, !id.isEmpty else { return }
        cache.removeObject(forKey: id as NSString)
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private static func squareCrop(_ image: UIImage, side: CGFloat) -> UIImage {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let w = image.size.width, h = image.size.height
            guard w > 0, h > 0 else { return }
            let scale = max(side / w, side / h)
            let drawn = CGSize(width: w * scale, height: h * scale)
            let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
    }
}
