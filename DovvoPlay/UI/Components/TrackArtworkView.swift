import SwiftUI

public struct TrackArtworkView: View {
    public let urlString: String?
    public let size: CGFloat
    public let cornerRadius: CGFloat
    public let placeholderIcon: String

    public init(
        urlString: String?,
        size: CGFloat = 48,
        cornerRadius: CGFloat = 10,
        placeholderIcon: String = "music.note"
    ) {
        self.urlString = urlString
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderIcon = placeholderIcon
    }

    public var body: some View {
        Group {
            if let str = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                if str.hasPrefix("http://") || str.hasPrefix("https://") {
                    AsyncImage(url: URL(string: str)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    let cleanPath = str.replacingOccurrences(of: "file://", with: "")
                    if let uiImage = UIImage(contentsOfFile: cleanPath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholderView: some View {
        ZStack {
            AppTheme.primaryGradient
            Image(systemName: placeholderIcon)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.black)
        }
    }
}
