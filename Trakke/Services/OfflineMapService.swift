import Foundation
@preconcurrency import MapLibre

// MARK: - Offline Pack Info

struct OfflinePackInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let layer: String
    let bounds: (south: Double, west: Double, north: Double, east: Double)
    let minZoom: Int
    let maxZoom: Int
    let progress: OfflineDownloadProgress
}

struct OfflineDownloadProgress: Sendable {
    let completedResources: UInt64
    let expectedResources: UInt64
    let completedBytes: UInt64
    let isComplete: Bool

    var percentage: Double {
        guard expectedResources > 0 else { return 0 }
        return Double(completedResources) / Double(expectedResources) * 100
    }

    static let zero = OfflineDownloadProgress(
        completedResources: 0,
        expectedResources: 0,
        completedBytes: 0,
        isComplete: false
    )
}

// MARK: - Pack Context

struct OfflinePackContext: Codable, Sendable {
    let id: String
    let name: String
    let layer: String
}

// MARK: - Offline Map Service

@MainActor
final class OfflineMapService {
    static let shared = OfflineMapService()
    nonisolated private static let tileSizeEstimate: Int64 = 15_000 // ~15 KB per tile

    private init() {}

    // MARK: - Tile Count Estimation

    nonisolated static func estimateTileCount(
        south: Double, west: Double, north: Double, east: Double,
        minZoom: Int, maxZoom: Int
    ) -> Int {
        var total = 0
        for z in minZoom...maxZoom {
            let n = pow(2.0, Double(z))
            let xMin = Int(floor((west + 180) / 360 * n))
            let xMax = Int(floor((east + 180) / 360 * n))
            let yMin = Int(floor((1 - log(tan(north * .pi / 180) + 1 / cos(north * .pi / 180)) / .pi) / 2 * n))
            let yMax = Int(floor((1 - log(tan(south * .pi / 180) + 1 / cos(south * .pi / 180)) / .pi) / 2 * n))
            total += (abs(xMax - xMin) + 1) * (abs(yMax - yMin) + 1)
        }
        return total
    }

    nonisolated static func estimateSize(tileCount: Int) -> Int64 {
        Int64(tileCount) * tileSizeEstimate
    }

    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }

    // MARK: - Download

    func startDownload(
        name: String,
        layer: BaseLayer,
        south: Double, west: Double, north: Double, east: Double,
        minZoom: Int, maxZoom: Int
    ) {
        let styleURL = KartverketTileService.styleURL(for: layer)

        let sw = CLLocationCoordinate2D(latitude: south, longitude: west)
        let ne = CLLocationCoordinate2D(latitude: north, longitude: east)
        let bounds = MLNCoordinateBounds(sw: sw, ne: ne)

        let region = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: bounds,
            fromZoomLevel: Double(minZoom),
            toZoomLevel: Double(maxZoom)
        )

        let packId = "dl-\(Int(Date().timeIntervalSince1970))-\(String(Int.random(in: 0...999999), radix: 36))"
        let context = OfflinePackContext(id: packId, name: name, layer: layer.rawValue)
        guard let contextData = try? JSONEncoder().encode(context) else { return }

        MLNOfflineStorage.shared.addPack(for: region, withContext: contextData) { pack, error in
            if let error {
                #if DEBUG
                print("Offline pack error: \(error)")
                #endif
                return
            }
            pack?.resume()
        }
    }

    // MARK: - Pack Management

    func getPacks() -> [OfflinePackInfo] {
        guard let packs = MLNOfflineStorage.shared.packs else { return [] }
        return packs.compactMap { packInfo(from: $0) }
    }

    func deletePack(_ info: OfflinePackInfo) {
        guard let packs = MLNOfflineStorage.shared.packs else { return }
        for pack in packs {
            if let ctx = decodeContext(pack.context), ctx.id == info.id {
                MLNOfflineStorage.shared.removePack(pack) { error in
                    if let error {
                        #if DEBUG
                        print("Delete pack error: \(error)")
                        #endif
                    }
                }
                return
            }
        }
    }

    func deleteAllPacks() {
        guard let packs = MLNOfflineStorage.shared.packs else { return }
        for pack in packs {
            MLNOfflineStorage.shared.removePack(pack) { _ in }
        }
    }

    func pausePack(_ info: OfflinePackInfo) {
        findPack(id: info.id)?.suspend()
    }

    func resumePack(_ info: OfflinePackInfo) {
        findPack(id: info.id)?.resume()
    }

    // MARK: - Helpers

    private func packInfo(from pack: MLNOfflinePack) -> OfflinePackInfo? {
        guard let ctx = decodeContext(pack.context),
              let region = pack.region as? MLNTilePyramidOfflineRegion else { return nil }

        let progress = pack.progress
        let dlProgress = OfflineDownloadProgress(
            completedResources: progress.countOfResourcesCompleted,
            expectedResources: progress.countOfResourcesExpected,
            completedBytes: progress.countOfBytesCompleted,
            isComplete: progress.countOfResourcesExpected == progress.countOfResourcesCompleted
                && progress.countOfResourcesExpected > 0
        )

        return OfflinePackInfo(
            id: ctx.id,
            name: ctx.name,
            layer: ctx.layer,
            bounds: (
                south: region.bounds.sw.latitude,
                west: region.bounds.sw.longitude,
                north: region.bounds.ne.latitude,
                east: region.bounds.ne.longitude
            ),
            minZoom: Int(region.minimumZoomLevel),
            maxZoom: Int(region.maximumZoomLevel),
            progress: dlProgress
        )
    }

    private func findPack(id: String) -> MLNOfflinePack? {
        MLNOfflineStorage.shared.packs?.first { pack in
            decodeContext(pack.context)?.id == id
        }
    }

    private func decodeContext(_ data: Data) -> OfflinePackContext? {
        try? JSONDecoder().decode(OfflinePackContext.self, from: data)
    }
}
