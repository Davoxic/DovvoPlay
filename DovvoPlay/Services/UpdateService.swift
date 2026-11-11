import Foundation
import UIKit
import Combine

public class UpdateService: ObservableObject {
    public static let shared = UpdateService()

    public static let currentVersion = "2.0.0"
    public static let repoOwner = "Davoxic"
    public static let repoName = "sonora"

    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var isDownloading: Bool = false
    @Published public private(set) var downloadProgress: Double = 0.0
    @Published public private(set) var downloadStatus: String = ""
    @Published public private(set) var latestRelease: AppReleaseInfo?
    @Published public private(set) var downloadedIpaURL: URL?

    private init() {}

    public static func isVersionNewer(remote: String, local: String) -> Bool {
        let cleanRemote = remote.replacingOccurrences(of: "v", with: "").components(separatedBy: ".").compactMap { Int($0) }
        let cleanLocal = local.replacingOccurrences(of: "v", with: "").components(separatedBy: ".").compactMap { Int($0) }

        var r = cleanRemote
        var l = cleanLocal
        while r.count < 3 { r.append(0) }
        while l.count < 3 { l.append(0) }

        for i in 0..<3 {
            if r[i] > l[i] { return true }
            if r[i] < l[i] { return false }
        }
        return false
    }

    @discardableResult
    public func checkForUpdates(isSilent: Bool = false) async -> AppReleaseInfo? {
        guard !isChecking else { return latestRelease }
        isChecking = true

        defer { isChecking = false }

        guard let url = URL(string: "https://api.github.com/repos/\(UpdateService.repoOwner)/\(UpdateService.repoName)/releases/latest") else {
            return nil
        }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("DovvoPlay-iOS", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            let tagName = json["tag_name"] as? String ?? ""
            let name = json["name"] as? String ?? tagName
            let body = json["body"] as? String ?? ""
            let htmlUrl = json["html_url"] as? String ?? "https://github.com/\(UpdateService.repoOwner)/\(UpdateService.repoName)/releases"

            var ipaUrl: String?
            var ipaSize: Int = 0
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    let assetName = (asset["name"] as? String)?.lowercased() ?? ""
                    if assetName.hasSuffix(".ipa") {
                        ipaUrl = asset["browser_download_url"] as? String
                        ipaSize = asset["size"] as? Int ?? 0
                        break
                    }
                }
            }

            let newer = UpdateService.isVersionNewer(remote: tagName, local: UpdateService.currentVersion)

            let release = AppReleaseInfo(
                tagName: tagName,
                name: name,
                body: body,
                ipaDownloadUrl: ipaUrl,
                ipaSize: ipaSize,
                publishedAt: nil,
                htmlUrl: htmlUrl,
                isNewer: newer
            )

            await MainActor.run {
                self.latestRelease = release
            }
            return release
        } catch {
            return nil
        }
    }

    public func downloadIpa(release: AppReleaseInfo, onProgress: ((Double, String) -> Void)? = nil) async -> URL? {
        guard let urlStr = release.ipaDownloadUrl, let url = URL(string: urlStr) else { return nil }

        await MainActor.run {
            self.isDownloading = true
            self.downloadProgress = 0.0
            self.downloadStatus = "Avvio download pacchetto .ipa..."
        }

        let docs = LibraryService.shared.documentsDirectory
        let targetURL = docs.appendingPathComponent("DovvoPlay-\(release.cleanVersion).ipa")

        if FileManager.default.fileExists(atPath: targetURL.path),
           let size = try? targetURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size == release.ipaSize, release.ipaSize > 0 {
            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.downloadStatus = "Download già completato!"
                self.downloadedIpaURL = targetURL
            }
            return targetURL
        }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadStatus = "Errore download dal server GitHub."
                }
                return nil
            }

            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.moveItem(at: tempURL, to: targetURL)

            await MainActor.run {
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.downloadStatus = "Download completato! Pronto per la firma locale."
                self.downloadedIpaURL = targetURL
            }
            return targetURL
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.downloadStatus = "Errore durante il download: \(error.localizedDescription)"
            }
            return nil
        }
    }

    public func shareIpa(fileURL: URL) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }

            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}
