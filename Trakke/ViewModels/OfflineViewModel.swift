import SwiftUI
@preconcurrency import MapLibre

@MainActor
@Observable
final class OfflineViewModel {
    var packs: [OfflinePackInfo] = []
    var isSelectingArea = false
    var selectionCorner1: CLLocationCoordinate2D?
    var selectionCorner2: CLLocationCoordinate2D?
    var downloadName = ""
    var downloadLayer: BaseLayer = .topo
    var downloadMinZoom = 8
    var downloadMaxZoom = 15
    var isDownloading = false

    private let service = OfflineMapService.shared
    private var progressObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

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

    // MARK: - Lifecycle

    func startObserving() {
        loadPacks()

        progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadPacks()
            }
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            #if DEBUG
            if let error = notification.userInfo?[MLNOfflinePackUserInfoKey.error] as? Error {
                print("Offline error: \(error)")
            }
            #endif
            Task { @MainActor in
                self?.loadPacks()
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
            minZoom: downloadMinZoom, maxZoom: downloadMaxZoom
        )

        isSelectingArea = false
        selectionCorner1 = nil
        selectionCorner2 = nil
        downloadName = ""

        // Download starts async, packs list will update via notification
        Task {
            try? await Task.sleep(for: .seconds(1))
            loadPacks()
            isDownloading = false
        }
    }

    // MARK: - Pack Management

    func loadPacks() {
        packs = service.getPacks()
    }

    func deletePack(_ pack: OfflinePackInfo) {
        service.deletePack(pack)
        loadPacks()
    }

    func pausePack(_ pack: OfflinePackInfo) {
        service.pausePack(pack)
    }

    func resumePack(_ pack: OfflinePackInfo) {
        service.resumePack(pack)
    }
}
