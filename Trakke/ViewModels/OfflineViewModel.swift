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
            self?.loadPacks()
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
            self?.loadPacks()
        }
    }

    func stopObserving() {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = errorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Area Selection

    func startSelection() {
        isSelectingArea = true
        selectionCorner1 = nil
        selectionCorner2 = nil
    }

    func cancelSelection() {
        isSelectingArea = false
        selectionCorner1 = nil
        selectionCorner2 = nil
    }

    func addSelectionPoint(_ coordinate: CLLocationCoordinate2D) {
        if selectionCorner1 == nil {
            selectionCorner1 = coordinate
        } else if selectionCorner2 == nil {
            selectionCorner2 = coordinate
        } else {
            selectionCorner1 = coordinate
            selectionCorner2 = nil
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.loadPacks()
            self?.isDownloading = false
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
