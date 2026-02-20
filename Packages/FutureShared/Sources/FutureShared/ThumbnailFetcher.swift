import UIKit
import LinkPresentation

public final class ThumbnailFetcher: Sendable {
    public static let shared = ThumbnailFetcher()
    private init() {}

    public func fetchThumbnail(for urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        let provider = LPMetadataProvider()
        provider.shouldFetchSubresources = false
        provider.timeout = 8

        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            guard let imageProvider = metadata.imageProvider else { return nil }
            let result = try await imageProvider.loadItem(forTypeIdentifier: "public.image")
            if let image = result as? UIImage {
                return image
            }
            if let data = result as? Data {
                return UIImage(data: data)
            }
            if let url = result as? URL, let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
            return nil
        } catch {
            return nil
        }
    }
}
