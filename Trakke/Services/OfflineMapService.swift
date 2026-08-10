import Foundation
import OSLog
@preconcurrency import MapLibre

// MARK: - Offline Pack Info

struct OfflinePackInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let layer: String
    let kommuneId: String?
    let bounds: (south: Double, west: Double, north: Double, east: Double)
    let minZoom: Int
    let maxZoom: Int
    let progress: OfflineDownloadProgress
    /// Sann bare mens MapLibre faktisk henter fliser. En pakke som er
    /// avbrutt (appen drept, nedlasting stanset) ser ellers helt lik ut som
    /// en som pågår – samme framdrift, samme tall, men den står stille.
    let isDownloading: Bool
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
    let kommuneId: String?

    init(id: String, name: String, layer: String, kommuneId: String? = nil) {
        self.id = id
        self.name = name
        self.layer = layer
        self.kommuneId = kommuneId
    }
}

// MARK: - Offline Map Service

@MainActor
final class OfflineMapService {
    static let shared = OfflineMapService()
    /// Målt gjennomsnitt for Kartverkets topografiske fliser, ikke et anslag:
    /// 8038 fliser i flisdatabasen ga 51,7 KB i snitt (6. august 2026). De
    /// detaljerte nivåene som dominerer en pakke lå på 47–48 KB, de grove på
    /// 78–127 KB, men de er så få at snittet trekkes mot de detaljerte.
    ///
    /// Verdien var 15 KB, altså 3,4 ganger for lavt. Gråtonekartet er lettere
    /// enn dette; anslaget er felles for alle kartlagene og treffer derfor
    /// topografisk og turkart best.
    ///
    nonisolated private static let tileSizeEstimate: Int64 = 50_000

    /// MapLibre henter i praksis rundt fire ganger så mange fliser som
    /// geometrien teller: raster-nedlastingen skjer på enhetens skalafaktor,
    /// så retina-skjermer henter fliser fra neste zoomnivå. Kalibrert mot
    /// Oslo-pakken: uten faktoren ble den anslått til 168 MB, men passerte
    /// 379 MB allerede på 57 prosent (reelt ca. 665 MB, altså ~4×).
    /// Faktoren ligger i `estimateTileCount`, ikke i flisstørrelsen, slik at
    /// flisantall og megabyte i UI-et forblir konsistente.
    nonisolated private static let deviceScaleFactor = 4

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
        return total * deviceScaleFactor
    }

    nonisolated static func estimateSize(tileCount: Int) -> Int64 {
        Int64(tileCount) * tileSizeEstimate
    }

    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_073_741_824 {
            return MeasurementService.withUnit(
                MeasurementService.decimal(Double(bytes) / 1_073_741_824, digits: 1), "GB")
        } else if bytes >= 1_048_576 {
            return MeasurementService.withUnit(
                MeasurementService.decimal(Double(bytes) / 1_048_576, digits: 1), "MB")
        } else if bytes >= 1024 {
            return MeasurementService.withUnit(
                MeasurementService.decimal(Double(bytes) / 1024, digits: 0), "KB")
        }
        return MeasurementService.withUnit("\(bytes)", "B")
    }

    /// Human-readable description of what a max zoom level provides for hiking.
    nonisolated static func zoomDescription(maxZoom: Int) -> String {
        switch maxZoom {
        case ...12: return String(localized: "offline.zoom.overview")
        case 13...14: return String(localized: "offline.zoom.good")
        default: return String(localized: "offline.zoom.detailed")
        }
    }

    // MARK: - Download

    func startDownload(
        name: String,
        layer: BaseLayer,
        south: Double, west: Double, north: Double, east: Double,
        minZoom: Int, maxZoom: Int,
        kommuneId: String? = nil
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
        let context = OfflinePackContext(id: packId, name: name, layer: layer.rawValue, kommuneId: kommuneId)
        guard let contextData = try? JSONEncoder().encode(context) else { return }

        MLNOfflineStorage.shared.addPack(for: region, withContext: contextData) { pack, error in
            if let error {
                Logger.offline.error("Offline pack error: \(error, privacy: .private)")
                return
            }
            pack?.resume()
        }
    }

    // MARK: - Pack Management

    func getPacks() -> [OfflinePackInfo] {
        guard let packs = MLNOfflineStorage.shared.packs else { return [] }
        // MapLibre regner framdriften for en inaktiv pakke først når den bes
        // om; fram til da er tilstanden `.unknown` og tellerne står på null.
        // Uten dette viste ferdige nedlastinger «0 B» og «Totalt lagret 0 B»,
        // og `isComplete` ble aldri sann – som igjen skjulte både «Vis området
        // på kartet» og «Oppdater». Svaret kommer som en
        // MLNOfflinePackProgressChanged-varsling, som `startObserving` allerede
        // lytter på og laster lista på nytt fra.
        for pack in packs where pack.state == .unknown {
            pack.requestProgress()
        }
        return packs.compactMap { packInfo(from: $0) }
    }

    func deletePack(_ info: OfflinePackInfo) {
        guard let packs = MLNOfflineStorage.shared.packs else { return }
        for pack in packs {
            if let ctx = decodeContext(pack.context), ctx.id == info.id {
                MLNOfflineStorage.shared.removePack(pack) { error in
                    if let error {
                        Logger.offline.error("Delete pack error: \(error, privacy: .private)")
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

    /// Gir pakken nytt navn. Navnet ligger i pakkens `context`, så det er den
    /// som skrives om – selve flisene røres ikke.
    /// `async` framfor completion-closure: MapLibres callback kjører utenfor
    /// MainActor, og en `@MainActor`-isolert closure sendt inn dit er en
    /// datakappløp-feil under Swift 6. Bare kontinuasjonen krysser grensen.
    func renamePack(_ info: OfflinePackInfo, to newName: String) async {
        guard let pack = findPack(id: info.id),
              let ctx = decodeContext(pack.context) else { return }
        let updated = OfflinePackContext(
            id: ctx.id,
            name: newName,
            layer: ctx.layer,
            kommuneId: ctx.kommuneId
        )
        guard let data = try? JSONEncoder().encode(updated) else { return }

        await withCheckedContinuation { continuation in
            pack.setContext(data) { error in
                if let error {
                    Logger.offline.error("Rename pack error: \(error, privacy: .private)")
                }
                continuation.resume()
            }
        }
    }

    /// Sjekker flisene mot serveren og henter bare dem som er endret.
    /// Vesentlig billigere enn å slette og laste ned på nytt, og er grunnen
    /// til at «oppdater» ikke er pakket inn som en ny nedlasting.
    func refreshPack(_ info: OfflinePackInfo) async {
        guard let pack = findPack(id: info.id) else { return }
        await withCheckedContinuation { continuation in
            MLNOfflineStorage.shared.invalidatePack(pack) { error in
                if let error {
                    Logger.offline.error("Refresh pack error: \(error, privacy: .private)")
                }
                continuation.resume()
            }
        }
    }

    func pausePack(_ info: OfflinePackInfo) {
        findPack(id: info.id)?.suspend()
    }

    func resumePack(_ info: OfflinePackInfo) {
        findPack(id: info.id)?.resume()
    }

    /// Clear the MapLibre ambient tile cache (non-offline tiles the user has viewed).
    func clearTileCache() {
        MLNOfflineStorage.shared.clearAmbientCache { error in
            if let error {
                Logger.offline.error("Failed to clear ambient tile cache: \(error, privacy: .private)")
            }
        }
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
            kommuneId: ctx.kommuneId,
            bounds: (
                south: region.bounds.sw.latitude,
                west: region.bounds.sw.longitude,
                north: region.bounds.ne.latitude,
                east: region.bounds.ne.longitude
            ),
            minZoom: Int(region.minimumZoomLevel),
            maxZoom: Int(region.maximumZoomLevel),
            progress: dlProgress,
            isDownloading: pack.state == .active
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
