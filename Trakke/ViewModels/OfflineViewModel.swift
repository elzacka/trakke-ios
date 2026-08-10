import SwiftUI
import OSLog
@preconcurrency import MapLibre

@MainActor
@Observable
final class OfflineViewModel {
    var packs: [OfflinePackInfo] = []
    /// Bounds for completed packs only – derived in `loadPacks()` so views can
    /// read it cheaply on every body without re-filtering.
    private(set) var completedPackBounds: [(south: Double, west: Double, north: Double, east: Double)] = []
    var isSelectingArea = false
    var selectionCorner1: CLLocationCoordinate2D?
    var selectionCorner2: CLLocationCoordinate2D?
    var downloadName = ""
    var downloadLayer: BaseLayer = .topo
    var downloadMinZoom = 8
    var downloadMaxZoom = 15
    var isDownloading = false

    // Kommune browsing
    var kommuner: [KommuneRegion] = []
    var kommuneSearchQuery = "" {
        didSet { if kommuneSearchQuery != oldValue { regroupKommuner() } }
    }
    var kommuneDownloadLayer: BaseLayer = .topo

    private let service: OfflineMapService
    private var progressObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    init(service: OfflineMapService = OfflineMapService.shared) {
        self.service = service
    }

    // MARK: - Kommune

    func loadKommuner() {
        guard kommuner.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "Kommuner", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(KommuneFile.self, from: data) else {
            Logger.offline.error("Failed to load Kommuner.json")
            return
        }
        kommuner = file.kommuner
        regroupKommuner()
    }

    var filteredKommuner: [KommuneRegion] {
        guard !kommuneSearchQuery.isEmpty else { return kommuner }
        return kommuner.filter {
            $0.name.localizedCaseInsensitiveContains(kommuneSearchQuery)
        }
    }

    /// Cached grouping – recomputed only when the inputs (`kommuner`, `kommuneSearchQuery`)
    /// change, so body evaluations during download progress ticks do not re-group and
    /// re-sort all 357 kommuner.
    private(set) var kommunerByFylke: [(fylke: String, kommuner: [KommuneRegion])] = []

    private func regroupKommuner() {
        let grouped = Dictionary(grouping: filteredKommuner, by: \.fylke)
        kommunerByFylke = grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { fylke in
                let sorted = grouped[fylke]!.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return (fylke: fylke, kommuner: sorted)
            }
    }

    func isKommuneDownloaded(_ kommune: KommuneRegion) -> Bool {
        packs.contains { $0.kommuneId == kommune.id }
    }

    func startKommuneDownload(_ kommune: KommuneRegion) {
        let maxZoom = kommune.optimalMaxZoom()
        isDownloading = true
        service.startDownload(
            name: kommune.name,
            layer: kommuneDownloadLayer,
            south: kommune.south, west: kommune.west,
            north: kommune.north, east: kommune.east,
            minZoom: 8, maxZoom: maxZoom,
            kommuneId: kommune.id
        )

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self else { return }
            loadPacks()
            isDownloading = false
        }
    }

    var selectionBounds: (south: Double, west: Double, north: Double, east: Double)? {
        guard let c1 = selectionCorner1, let c2 = selectionCorner2 else { return nil }
        return (
            south: min(c1.latitude, c2.latitude),
            west: min(c1.longitude, c2.longitude),
            north: max(c1.latitude, c2.latitude),
            east: max(c1.longitude, c2.longitude)
        )
    }

    var estimatedTileCount: Int {
        guard let b = selectionBounds else { return 0 }
        return OfflineMapService.estimateTileCount(
            south: b.south, west: b.west, north: b.north, east: b.east,
            minZoom: downloadMinZoom, maxZoom: downloadMaxZoom
        )
    }

    var estimatedSize: String {
        OfflineMapService.formatBytes(OfflineMapService.estimateSize(tileCount: estimatedTileCount))
    }

    // MARK: - Offline Awareness

    /// Whether the user's current position is inside any completed offline pack.
    func isInsideOfflineArea(_ location: CLLocationCoordinate2D) -> Bool {
        packs.filter(\.progress.isComplete).contains { pack in
            location.latitude >= pack.bounds.south &&
            location.latitude <= pack.bounds.north &&
            location.longitude >= pack.bounds.west &&
            location.longitude <= pack.bounds.east
        }
    }

    private var wasInsideOfflineArea = true
    var showLeftAreaWarning = false

    /// Call when connectivity is lost and location updates. Shows a one-time warning
    /// when the user moves outside all downloaded areas while offline.
    func checkOfflineAreaBoundary(location: CLLocationCoordinate2D, isConnected: Bool) {
        guard !isConnected, !packs.filter(\.progress.isComplete).isEmpty else { return }
        let isInside = isInsideOfflineArea(location)
        if wasInsideOfflineArea && !isInside {
            showLeftAreaWarning = true
        }
        wasInsideOfflineArea = isInside
    }

    var completionMessage: String?
    /// IDs of packs that have encountered a download error and are now stalled.
    var erroredPackIDs: Set<String> = []
    /// Set to true when the user backgrounds the app while a download is in progress;
    /// cleared automatically after the warning toast auto-dismisses.
    var showDownloadBackgroundWarning = false

    func isErrored(_ pack: OfflinePackInfo) -> Bool {
        erroredPackIDs.contains(pack.id)
    }

    func retryPack(_ pack: OfflinePackInfo) {
        erroredPackIDs.remove(pack.id)
        service.resumePack(pack)
        loadPacks()
    }

    // MARK: - Lifecycle

    func startObserving() {
        stopObserving()
        loadPacks()

        progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let previousComplete = Set(self.packs.filter(\.progress.isComplete).map(\.id))
                self.loadPacks()
                let newlyComplete = self.packs.filter { $0.progress.isComplete && !previousComplete.contains($0.id) }
                if let first = newlyComplete.first {
                    self.completionMessage = first.name
                }
            }
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[MLNOfflinePackUserInfoKey.error] as? Error {
                Logger.offline.error("Offline pack error: \(error, privacy: .private)")
            }
            // Extract Sendable Data before crossing actor boundary
            let contextData: Data? = (notification.object as? MLNOfflinePack).map { $0.context }
            Task { @MainActor in
                guard let self else { return }
                if let data = contextData,
                   let ctx = try? JSONDecoder().decode(OfflinePackContext.self, from: data) {
                    self.erroredPackIDs.insert(ctx.id)
                }
                self.loadPacks()
            }
        }
    }

    func stopObserving() {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
            progressObserver = nil
        }
        if let observer = errorObserver {
            NotificationCenter.default.removeObserver(observer)
            errorObserver = nil
        }
    }

    // MARK: - Area Selection

    func startSelection(center: CLLocationCoordinate2D, zoom: Double) {
        isSelectingArea = true

        // Default rectangle: ~60px from center (~30% of viewport width)
        let metersPerPixel = 156543.03392 * cos(center.latitude * .pi / 180) / pow(2, zoom)
        let spanMeters = metersPerPixel * 60
        let latDelta = spanMeters / 111320
        let lonDelta = spanMeters / (111320 * cos(center.latitude * .pi / 180))

        selectionCorner1 = CLLocationCoordinate2D(
            latitude: center.latitude - latDelta,
            longitude: center.longitude - lonDelta
        )
        selectionCorner2 = CLLocationCoordinate2D(
            latitude: center.latitude + latDelta,
            longitude: center.longitude + lonDelta
        )
    }

    func cancelSelection() {
        isSelectingArea = false
        selectionCorner1 = nil
        selectionCorner2 = nil
    }

    func moveSelectionCorner(at index: Int, to coordinate: CLLocationCoordinate2D) {
        guard var c1 = selectionCorner1, var c2 = selectionCorner2 else { return }

        switch index {
        case 0: // SW
            c1 = coordinate
        case 1: // NW
            c1 = CLLocationCoordinate2D(latitude: c1.latitude, longitude: coordinate.longitude)
            c2 = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: c2.longitude)
        case 2: // NE
            c2 = coordinate
        case 3: // SE
            c1 = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: c1.longitude)
            c2 = CLLocationCoordinate2D(latitude: c2.latitude, longitude: coordinate.longitude)
        default: break
        }

        // Normalize so corner1 is always SW, corner2 is always NE
        let south = min(c1.latitude, c2.latitude)
        let north = max(c1.latitude, c2.latitude)
        let west = min(c1.longitude, c2.longitude)
        let east = max(c1.longitude, c2.longitude)

        selectionCorner1 = CLLocationCoordinate2D(latitude: south, longitude: west)
        selectionCorner2 = CLLocationCoordinate2D(latitude: north, longitude: east)
    }

    var hasValidSelection: Bool {
        selectionCorner1 != nil && selectionCorner2 != nil
    }

    // MARK: - Download

    func startDownload() {
        guard let b = selectionBounds, !downloadName.isEmpty else { return }
        guard estimatedTileCount <= 20_000 else { return }

        isDownloading = true
        service.startDownload(
            name: downloadName,
            layer: downloadLayer,
            south: b.south, west: b.west, north: b.north, east: b.east,
            minZoom: downloadMinZoom, maxZoom: downloadMaxZoom,
            kommuneId: nil
        )

        isSelectingArea = false
        selectionCorner1 = nil
        selectionCorner2 = nil
        downloadName = ""

        // Download starts async, packs list will update via notification
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self else { return }
            loadPacks()
            isDownloading = false
        }
    }

    // MARK: - Pack Management

    func loadPacks() {
        packs = service.getPacks()
        completedPackBounds = packs.compactMap { $0.progress.isComplete ? $0.bounds : nil }
    }

    func deletePack(_ pack: OfflinePackInfo) {
        service.deletePack(pack)
        loadPacks()
    }

    /// Tomt eller bare mellomrom avvises – en pakke uten navn er umulig å
    /// skille fra de andre i lista.
    func renamePack(_ pack: OfflinePackInfo, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { [weak self] in
            await self?.service.renamePack(pack, to: trimmed)
            self?.loadPacks()
        }
    }

    /// Pakker som oppdateres nå. Raden viser det, så brukeren ikke trykker
    /// igjen i troen på at ingenting skjedde – oppdateringen er stille når
    /// flisene allerede er ferske.
    var refreshingPackIds: Set<String> = []

    func refreshPack(_ pack: OfflinePackInfo) {
        guard !refreshingPackIds.contains(pack.id) else { return }
        refreshingPackIds.insert(pack.id)
        Task { [weak self] in
            await self?.service.refreshPack(pack)
            guard let self else { return }
            self.refreshingPackIds.remove(pack.id)
            self.loadPacks()
        }
    }

    func pausePack(_ pack: OfflinePackInfo) {
        service.pausePack(pack)
    }

    func resumePack(_ pack: OfflinePackInfo) {
        service.resumePack(pack)
    }
}
