import UIKit

public final class ThumbnailStore: Sendable {
    public static let shared = ThumbnailStore()

    private let containerURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fsayed.Future")?
        .appendingPathComponent("thumbnails", isDirectory: true)

    private init() {
        guard let containerURL else { return }
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
    }

    public func save(_ image: UIImage, for itemId: UUID) {
        guard let containerURL else { return }
        let downsized = downsample(image, maxDimension: 200)
        guard let data = downsized.jpegData(compressionQuality: 0.7) else { return }
        let fileURL = containerURL.appendingPathComponent("\(itemId.uuidString).jpg")
        try? data.write(to: fileURL, options: .atomic)
    }

    public func load(for itemId: UUID) -> UIImage? {
        guard let containerURL else { return nil }
        let fileURL = containerURL.appendingPathComponent("\(itemId.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    public func delete(for itemId: UUID) {
        guard let containerURL else { return }
        let fileURL = containerURL.appendingPathComponent("\(itemId.uuidString).jpg")
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
