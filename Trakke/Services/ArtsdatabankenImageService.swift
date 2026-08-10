import Foundation
import OSLog
import SwiftUI

/// Fetches and caches species profile images from Artsdatabanken.
///
/// Image pipeline: scientific name -> media ID (from catalog) -> WebP image data -> UIImage.
/// The catalog is fetched once and cached for the session. Individual images are cached
/// in URLCache (via APIClient.session) with Artsdatabanken's 8-hour cache-control.
actor ArtsdatabankenImageService {
    static let `default` = ArtsdatabankenImageService()

    private static let catalogURL = URL(string: "https://ai.artsdatabanken.no/taxon/images")!
    private static let mediaBaseURL = URL(string: "https://artsdatabanken.no/Media")!
    private static let imageSize = "480x480"

    private var catalog: [String: String]?

    /// NSCache evicts on system memory pressure – actor-safe because NSCache
    /// performs its own internal locking and is documented thread-safe.
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()

    /// Fetch a species profile image by scientific name.
    /// Returns nil if no image is available or on network failure.
    func image(for scientificName: String) async -> UIImage? {
        let key = scientificName as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        guard let mediaID = await mediaID(for: scientificName) else {
            return nil
        }

        let url = Self.mediaBaseURL
            .appendingPathComponent(mediaID)
            .appending(queryItems: [URLQueryItem(name: "mode", value: Self.imageSize)])

        do {
            let data = try await APIClient.fetchData(url: url, optional: true)
            guard let image = UIImage(data: data) else {
                Logger.knowledge.warning("Failed to decode image for \(scientificName, privacy: .public)")
                return nil
            }
            let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
            imageCache.setObject(image, forKey: key, cost: cost)
            return image
        } catch {
            Logger.knowledge.error("Failed to fetch image for \(scientificName, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear all cached images and the catalog. Called by "Slett alle data".
    func clearCache() {
        imageCache.removeAllObjects()
        catalog = nil
        catalogTask = nil
    }

    // MARK: - Private

    private func mediaID(for scientificName: String) async -> String? {
        if catalog == nil {
            await loadCatalog()
        }
        return catalog?[scientificName]
    }

    private var catalogTask: Task<[String: String]?, Never>?
    private let decoder = JSONDecoder()

    private func loadCatalog() async {
        if let existing = catalogTask {
            catalog = await existing.value
            // A memoized *failure* must not poison the session: drop the
            // completed-with-nil task so the next request retries the network.
            if catalog == nil { catalogTask = nil }
            return
        }
        let task = Task<[String: String]?, Never> {
            do {
                let data = try await APIClient.fetchData(url: Self.catalogURL, optional: true)
                let result = try self.decoder.decode([String: String].self, from: data)
                Logger.knowledge.info("Loaded Artsdatabanken image catalog: \(result.count) species")
                return result
            } catch {
                Logger.knowledge.error("Failed to load Artsdatabanken catalog: \(error.localizedDescription, privacy: .private)")
                return nil
            }
        }
        catalogTask = task
        catalog = await task.value
        if catalog == nil { catalogTask = nil }
    }

}
