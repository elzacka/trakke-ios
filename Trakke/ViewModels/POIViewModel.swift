import SwiftUI
import CoreLocation

@MainActor
@Observable
final class POIViewModel {
    var enabledCategories: Set<POICategory> = []
    var pois: [POI] = []
    var selectedPOI: POI?
    var isLoading = false

    private let poiService: POIService
    private var loadTask: Task<Void, Never>?
    private var lastBounds: ViewportBounds?
    private var lastZoom: Double = 0
    private static let debounceInterval: Duration = .milliseconds(1500)
    private static let maxAnnotations = 2000

    init(poiService: POIService = POIService()) {
        self.poiService = poiService
    }

    func toggleCategory(_ category: POICategory) {
        if enabledCategories.contains(category) {
            enabledCategories.remove(category)
            pois.removeAll { $0.category == category }
        } else {
            enabledCategories.insert(category)
            guard let bounds = lastBounds else { return }

            // Sørg for at bundled-cache er populert før vi spør om POI-er.
            // Uten dette ville en kategori som er enablet før preloadAll når
            // den i køen returnere tomt resultat – POI-er ville ikke vises
            // før neste viewport-endring (race condition).
            if category.isBundled {
                Task { [weak self] in
                    await BundledPOIService.loadIfNeeded(category)
                    guard let self,
                          self.enabledCategories.contains(category) else { return }
                    self.loadCategory(category, bounds: bounds, zoom: self.lastZoom)
                }
            } else {
                loadCategory(category, bounds: bounds, zoom: lastZoom)
            }
        }
    }

    /// Slå av alle kategorier samtidig. Brukt av Kategorier-velgeren.
    func disableAllCategories() {
        enabledCategories.removeAll()
        pois.removeAll()
    }

    private func loadCategory(_ category: POICategory, bounds: ViewportBounds, zoom: Double) {
        guard zoom >= category.minZoom else {
            pois.removeAll { $0.category == category }
            return
        }

        if category.isBundled {
            // Show bundled data immediately
            let newPOIs = BundledPOIService.pois(for: category, in: bounds.buffered())
            pois.removeAll { $0.category == category }
            pois.append(contentsOf: newPOIs)
        }

        if category.isLive {
            // Refresh from live API (replaces bundled data when successful)
            let service = poiService
            Task { [weak self] in
                guard let self else { return }
                isLoading = true
                let newPOIs = await service.fetchPOIs(category: category, bounds: bounds, zoom: zoom)
                guard enabledCategories.contains(category) else {
                    isLoading = false
                    return
                }
                pois.removeAll { $0.category == category }
                pois.append(contentsOf: newPOIs)
                isLoading = false
            }
        }
        enforceAnnotationLimit()
    }

    func viewportChanged(bounds: ViewportBounds, zoom: Double) {
        lastBounds = bounds
        lastZoom = zoom

        guard !enabledCategories.isEmpty else { return }

        // Update bundled categories immediately (no network cost)
        let bundledCategories = enabledCategories.filter(\.isBundled)
        let buffered = bounds.buffered()
        for category in bundledCategories {
            if zoom < category.minZoom {
                pois.removeAll { $0.category == category }
            } else {
                let result = BundledPOIService.pois(for: category, in: buffered)
                pois.removeAll { $0.category == category }
                pois.append(contentsOf: result)
            }
        }

        // Debounce live categories (network requests) -- includes hybrid categories
        let liveCategories = enabledCategories.filter(\.isLive)
        guard !liveCategories.isEmpty else {
            enforceAnnotationLimit()
            return
        }

        loadTask?.cancel()
        let service = poiService
        loadTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled, let self else { return }

            isLoading = true

            for category in liveCategories {
                guard !Task.isCancelled else { return }
                let result = await service.fetchPOIs(category: category, bounds: bounds, zoom: zoom)
                guard !Task.isCancelled else { return }
                pois.removeAll { $0.category == category }
                pois.append(contentsOf: result)
            }

            pois.removeAll { !enabledCategories.contains($0.category) }
            enforceAnnotationLimit()
            isLoading = false
        }
    }

    /// Taket på antall markører deles likt mellom kategoriene som er på.
    ///
    /// Før tok den `prefix(maxAnnotations)` av hele lista. Live-kategorier
    /// legges til sist i `viewportChanged`, så det var alltid de som ble
    /// kuttet – og kulturminner, den eneste rent live-kategorien, kunne
    /// forsvinne helt fra kartet så snart nok bunter var slått på i et tett
    /// område. Kategorien så ut til å være i stykker, men var bare kuttet
    /// bort etter at den var hentet.
    private func enforceAnnotationLimit() {
        guard pois.count > Self.maxAnnotations else { return }

        // Bevar rekkefølgen kategoriene dukket opp i, så kartet ikke
        // stokker om på seg selv mellom oppdateringer.
        var order: [POICategory] = []
        for poi in pois where !order.contains(poi.category) {
            order.append(poi.category)
        }
        guard order.count > 1 else {
            pois = Array(pois.prefix(Self.maxAnnotations))
            return
        }

        let quota = max(1, Self.maxAnnotations / order.count)
        var kept: [POI] = []
        for category in order {
            kept.append(contentsOf: pois.filter { $0.category == category }.prefix(quota))
        }
        pois = kept
    }

    func selectPOI(_ poi: POI) {
        selectedPOI = poi
    }

    func clearSelection() {
        selectedPOI = nil
    }

    func clearCaches() async {
        await poiService.clearCache()
    }
}
