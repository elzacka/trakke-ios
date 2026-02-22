import SwiftUI
import SwiftData
import CoreLocation
import os

private let logger = Logger(subsystem: "no.tazk.trakke", category: "WaypointViewModel")

@MainActor
@Observable
final class WaypointViewModel {
    var waypoints: [Waypoint] = []
    var selectedWaypoint: Waypoint?
    var isPlacingWaypoint = false
    var placingCoordinate: CLLocationCoordinate2D?
    var importMessage: String?
    var saveError: String?

    private var modelContext: ModelContext?
    private let elevationService = ElevationService()

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    private func save(_ operation: String) {
        do {
            try modelContext?.save()
        } catch {
            logger.error("Failed to save (\(operation)): \(error, privacy: .private)")
            saveError = String(localized: "error.saveFailed")
        }
    }

    // MARK: - CRUD

    func loadWaypoints() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Waypoint>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        waypoints = (try? context.fetch(descriptor)) ?? []
    }

    func addWaypoint(name: String, coordinate: CLLocationCoordinate2D, category: String?) {
        guard let context = modelContext else { return }
        let trimmedCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines)
        let wp = Waypoint(
            name: name,
            coordinates: [coordinate.longitude, coordinate.latitude],
            category: trimmedCategory?.isEmpty == true ? nil : trimmedCategory
        )
        context.insert(wp)
        save("waypoint")
        loadWaypoints()

        Task {
            await fetchElevation(for: wp)
        }
    }

    func updateWaypoint(_ waypoint: Waypoint, name: String, category: String?) {
        let trimmedCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines)
        waypoint.name = name
        waypoint.category = trimmedCategory?.isEmpty == true ? nil : trimmedCategory
        waypoint.updatedAt = Date()
        save("waypoint")
        loadWaypoints()
    }

    func deleteWaypoint(_ waypoint: Waypoint) {
        guard let context = modelContext else { return }
        context.delete(waypoint)
        save("waypoint")
        loadWaypoints()
    }

    func toggleVisibility(_ waypoint: Waypoint) {
        waypoint.isVisible.toggle()
        waypoint.updatedAt = Date()
        save("waypoint")
        loadWaypoints()
    }

    func setCategoryVisibility(_ category: String?, visible: Bool) {
        let items: [Waypoint]
        if let category {
            items = waypoints(for: category)
        } else {
            items = uncategorizedWaypoints
        }
        for wp in items {
            wp.isVisible = visible
            wp.updatedAt = Date()
        }
        save("waypoint")
        loadWaypoints()
    }

    func isCategoryAllVisible(_ category: String?) -> Bool {
        let items: [Waypoint]
        if let category {
            items = waypoints(for: category)
        } else {
            items = uncategorizedWaypoints
        }
        return !items.isEmpty && items.allSatisfy(\.isVisible)
    }

    // MARK: - Computed

    var categories: [String] {
        let cats = Set(waypoints.compactMap(\.category))
        return cats.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var visibleWaypoints: [Waypoint] {
        waypoints.filter(\.isVisible)
    }

    func waypoints(for category: String) -> [Waypoint] {
        waypoints
            .filter { $0.category == category }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var uncategorizedWaypoints: [Waypoint] {
        waypoints
            .filter { $0.category == nil || $0.category?.isEmpty == true }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Placement

    func startPlacing(at coordinate: CLLocationCoordinate2D) {
        isPlacingWaypoint = true
        placingCoordinate = coordinate
    }

    func cancelPlacing() {
        isPlacingWaypoint = false
        placingCoordinate = nil
    }

    // MARK: - Elevation

    func fetchElevation(for waypoint: Waypoint) async {
        guard waypoint.coordinates.count >= 2 else { return }
        let coord = CLLocationCoordinate2D(
            latitude: waypoint.coordinates[1],
            longitude: waypoint.coordinates[0]
        )
        if let elevation = await elevationService.fetchElevation(coordinate: coord) {
            waypoint.elevation = elevation
            waypoint.updatedAt = Date()
            save("waypoint")
            loadWaypoints()
        }
    }

    // MARK: - GPX Export

    func exportAllGPX() -> URL? {
        let gpxString = GPXExportService.exportWaypoints(waypoints)
        return GPXExportService.writeToTemporaryFile(
            gpxString: gpxString,
            filename: "mine_steder.gpx"
        )
    }

    func exportCategoryGPX(category: String) -> URL? {
        let filtered = waypoints(for: category)
        let gpxString = GPXExportService.exportWaypoints(filtered, name: category)
        let filename = GPXExportService.sanitizeFilename(category)
        return GPXExportService.writeToTemporaryFile(gpxString: gpxString, filename: filename)
    }

    // MARK: - GPX Import

    func importGPX(from url: URL) {
        guard let context = modelContext else { return }
        do {
            let imported = try GPXImportService.parseWaypoints(from: url)
            guard !imported.isEmpty else {
                importMessage = String(localized: "waypoints.importError")
                return
            }

            var count = 0
            for item in imported {
                let wp = Waypoint(
                    name: item.name,
                    coordinates: [item.longitude, item.latitude],
                    category: item.category,
                    elevation: item.elevation
                )
                context.insert(wp)
                count += 1
            }
            save("waypoint")
            loadWaypoints()
            importMessage = String(localized: "waypoints.importSuccess \(count)")
        } catch {
            importMessage = String(localized: "waypoints.importError")
        }
    }
}
