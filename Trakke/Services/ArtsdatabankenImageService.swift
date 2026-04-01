import Foundation
import OSLog
import SwiftUI

/// Protocol for dependency injection and testability.
protocol ArtsdatabankenImageProviding: Sendable {
    func image(for scientificName: String) async -> UIImage?
    func clearCache() async
}

/// Fetches and caches species profile images from Artsdatabanken.
///
/// Image pipeline: scientific name -> media ID (from catalog) -> WebP image data -> UIImage.
/// The catalog is fetched once and cached for the session. Individual images are cached
/// in URLCache (via APIClient.session) with Artsdatabanken's 8-hour cache-control.
actor ArtsdatabankenImageService: ArtsdatabankenImageProviding {
    static let `default` = ArtsdatabankenImageService()

    private static let catalogURL = "https://ai.artsdatabanken.no/taxon/images"
    private static let mediaBaseURL = "https://artsdatabanken.no/Media"
    private static let imageSize = "480x480"
    private static let maxCacheEntries = 30

    private var catalog: [String: String]?
    private var imageCache: [String: UIImage] = [:]
    private var cacheOrder: [String] = []

    /// Fetch a species profile image by scientific name.
    /// Returns nil if no image is available or on network failure.
    func image(for scientificName: String) async -> UIImage? {
        if let cached = imageCache[scientificName] {
            return cached
        }

        guard let mediaID = await mediaID(for: scientificName) else {
            return nil
        }

        guard let url = URL(string: "\(Self.mediaBaseURL)/\(mediaID)?mode=\(Self.imageSize)") else {
            return nil
        }

        do {
            let data = try await APIClient.fetchData(url: url, optional: true)
            guard let image = UIImage(data: data) else {
                Logger.knowledge.warning("Failed to decode image for \(scientificName, privacy: .public)")
                return nil
            }
            insertCache(scientificName, image: image)
            return image
        } catch {
            Logger.knowledge.error("Failed to fetch image for \(scientificName, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear all cached images and the catalog. Called by "Slett alle data".
    func clearCache() {
        imageCache.removeAll()
        cacheOrder.removeAll()
        catalog = nil
    }

    // MARK: - Private

    /// Look up media ID from the catalog, fetching it if needed.
    private func mediaID(for scientificName: String) async -> String? {
        if catalog == nil {
            await loadCatalog()
        }
        return catalog?[scientificName]
    }

    private func loadCatalog() async {
        guard let url = URL(string: Self.catalogURL) else { return }

        do {
            let data = try await APIClient.fetchData(url: url, optional: true)
            catalog = try JSONDecoder().decode([String: String].self, from: data)
            Logger.knowledge.info("Loaded Artsdatabanken image catalog: \(self.catalog?.count ?? 0) species")
        } catch {
            Logger.knowledge.error("Failed to load Artsdatabanken catalog: \(error.localizedDescription, privacy: .private)")
            // Leave catalog as nil so next call retries
        }
    }

    private func insertCache(_ key: String, image: UIImage) {
        imageCache[key] = image
        cacheOrder.append(key)
        while cacheOrder.count > Self.maxCacheEntries {
            let evicted = cacheOrder.removeFirst()
            imageCache.removeValue(forKey: evicted)
        }
    }
}
