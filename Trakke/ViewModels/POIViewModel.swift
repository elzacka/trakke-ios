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
    private static let debounceInterval: Duration = .milliseconds(1000)

    func toggleCategory(_ category: POICategory) {
        if enabledCategories.contains(category) {
            enabledCategories.remove(category)
            pois.removeAll { $0.category == category }
        } else {
            enabledCategories.insert(category)
            if let bounds = lastBounds {
                loadPOIs(bounds: bounds, zoom: lastZoom)
            }
        }
    }

    func viewportChanged(bounds: ViewportBounds, zoom: Double) {
        lastBounds = bounds
        lastZoom = zoom

        guard !enabledCategories.isEmpty else { return }

        loadTask?.cancel()
        let service = poiService
        let categories = enabledCategories
        loadTask = Task {
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }

            self.isLoading = true

            await withTaskGroup(of: [POI].self) { group in
                for category in categories {
                    group.addTask {
                        await service.fetchPOIs(category: category, bounds: bounds, zoom: zoom)
                    }
                }

                var allPOIs: [POI] = []
                for await result in group {
                    allPOIs.append(contentsOf: result)
                }

                guard !Task.isCancelled else { return }
                self.pois = allPOIs
            }

            self.isLoading = false
        }
    }

    func selectPOI(_ poi: POI) {
        selectedPOI = poi
    }

    func clearSelection() {
        selectedPOI = nil
    }

    private func loadPOIs(bounds: ViewportBounds, zoom: Double) {
        viewportChanged(bounds: bounds, zoom: zoom)
    }
}
