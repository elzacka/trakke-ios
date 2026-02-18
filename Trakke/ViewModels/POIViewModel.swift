import SwiftUI
import CoreLocation

@MainActor
@Observable
final class POIViewModel {
    var enabledCategories: Set<POICategory> = []
    var pois: [POI] = []
    var selectedPOI: POI?
    var isLoading = false

    private let poiService = POIService()
    private var loadTask: Task<Void, Never>?
    private var lastBounds: ViewportBounds?
    private var lastZoom: Double = 0
    private static let debounceInterval: Duration = .milliseconds(1500)

    func toggleCategory(_ category: POICategory) {
        if enabledCategories.contains(category) {
            enabledCategories.remove(category)
            pois.removeAll { $0.category == category }
        } else {
            enabledCategories.insert(category)
            if let bounds = lastBounds {
                loadCategory(category, bounds: bounds, zoom: lastZoom)
            }
        }
    }

    private func loadCategory(_ category: POICategory, bounds: ViewportBounds, zoom: Double) {
        if category.isBundled {
            let newPOIs = BundledPOIService.pois(for: category, in: bounds.buffered())
            pois.removeAll { $0.category == category }
            pois.append(contentsOf: newPOIs)
        } else {
            let service = poiService
            Task {
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
    }

    func viewportChanged(bounds: ViewportBounds, zoom: Double) {
        lastBounds = bounds
        lastZoom = zoom

        guard !enabledCategories.isEmpty else { return }

        // Update bundled categories immediately (no network cost)
        let bundledCategories = enabledCategories.filter(\.isBundled)
        let buffered = bounds.buffered()
        for category in bundledCategories {
            let result = BundledPOIService.pois(for: category, in: buffered)
            pois.removeAll { $0.category == category }
            pois.append(contentsOf: result)
        }

        // Debounce live categories (network requests)
        let liveCategories = enabledCategories.filter { !$0.isBundled }
        guard !liveCategories.isEmpty else { return }

        loadTask?.cancel()
        let service = poiService
        loadTask = Task {
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }

            self.isLoading = true

            for category in liveCategories {
                guard !Task.isCancelled else { return }
                let result = await service.fetchPOIs(category: category, bounds: bounds, zoom: zoom)
                guard !Task.isCancelled else { return }
                self.pois.removeAll { $0.category == category }
                self.pois.append(contentsOf: result)
            }

            self.pois.removeAll { !self.enabledCategories.contains($0.category) }
            self.isLoading = false
        }
    }

    func selectPOI(_ poi: POI) {
        selectedPOI = poi
    }

    func clearSelection() {
        selectedPOI = nil
    }
}
