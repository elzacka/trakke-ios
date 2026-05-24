import SwiftUI
import SwiftData
import CoreLocation
import OSLog

@MainActor
@Observable
final class WaypointViewModel {
    var waypoints: [Waypoint] = []
    var selectedWaypoint: Waypoint?
    var isPlacingWaypoint = false
    var placingCoordinate: CLLocationCoordinate2D?
    var importMessage: String?
    var isImporting = false
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
            Logger.waypoints.error("Failed to save (\(operation)): \(error, privacy: .private)")
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

        Task { [weak self] in
            await self?.fetchElevation(for: wp)
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

    func deleteAllWaypoints() {
        guard let context = modelContext else { return }
        do {
            try context.delete(model: Waypoint.self)
            save("waypoint")
            loadWaypoints()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func toggleVisibility(_ waypoint: Waypoint) {
        waypoint.isVisible.toggle()
        waypoint.updatedAt = Date()
        save("waypoint")
    }

    func setCategoryVisibility(_ category: String?, visible: Bool) {
        let items: [Waypoint]
        if let category {
            items = waypoints(for: category)
        } else {
            items = uncategorizedWaypoints
        }
        let now = Date()
        for wp in items where wp.isVisible != visible {
            wp.isVisible = visible
            wp.updatedAt = now
        }
        save("waypoint")
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

    /// Show only this waypoint — hide everything else.
    /// One SwiftData transaction so the map redraws once.
    func showOnly(_ waypoint: Waypoint) {
        let now = Date()
        for wp in waypoints where wp.id != waypoint.id && wp.isVisible {
            wp.isVisible = false
            wp.updatedAt = now
        }
        if !waypoint.isVisible {
            waypoint.isVisible = true
            waypoint.updatedAt = now
        }
        save("show only waypoint")
    }

    func setAllVisible(_ visible: Bool) {
        let now = Date()
        for wp in waypoints where wp.isVisible != visible {
            wp.isVisible = visible
            wp.updatedAt = now
        }
        save("set all waypoints visible")
    }

    var isAnyVisible: Bool {
        waypoints.contains(where: \.isVisible)
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
        }
    }

    // MARK: - Export

    func exportAllGPX() -> URL? {
        let gpxString = GPXExportService.exportWaypoints(waypoints)
        return GPXExportService.writeToTemporaryFile(
            gpxString: gpxString,
            filename: "mine_steder.gpx"
        )
    }

    /// Eksporter ett enkelt sted som GPX — brukes fra detaljvisningen.
    func exportGPX(for waypoint: Waypoint) -> URL? {
        let gpxString = GPXExportService.exportWaypoint(waypoint)
        let filename = GPXExportService.sanitizeFilename(waypoint.name)
        return GPXExportService.writeToTemporaryFile(gpxString: gpxString, filename: filename)
    }

    func exportCategoryGPX(category: String) -> URL? {
        let filtered = waypoints(for: category)
        let gpxString = GPXExportService.exportWaypoints(filtered, name: category)
        let filename = GPXExportService.sanitizeFilename(category)
        return GPXExportService.writeToTemporaryFile(gpxString: gpxString, filename: filename)
    }

    // MARK: - Import

    /// Detects file format from extension and routes to the appropriate parser.
    /// Synchronous import — dispatches to the right parser by file extension.
    /// GPX and GeoJSON share the same `ImportedWaypoint` intermediate type.
    @discardableResult
    func importFile(from url: URL) -> Int {
        do {
            let imported = try FileImporter.parse(
                from: url,
                gpx: GPXImportService.parseWaypoints,
                geoJSON: { try GeoJSONImportService.parse(from: $0).waypoints }
            )
            return insertImported(imported, filename: url.importedItemName)
        } catch FileImportError.unsupportedFormat {
            importMessage = String(localized: "import.error.unsupportedFormat")
            return 0
        } catch {
            importMessage = String(localized: "waypoints.importError")
            Logger.waypoints.error("Waypoint import failed: \(error, privacy: .private)")
            return 0
        }
    }

    /// Async variant used by the in-app file importer flow. Parses off the main
    /// actor so the UI can render the pending state.
    @discardableResult
    func importFileAsync(from url: URL) async -> Int {
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await FileImporter.parseOffActor(
                from: url,
                gpx: GPXImportService.parseWaypoints,
                geoJSON: { try GeoJSONImportService.parse(from: $0).waypoints }
            )
            return insertImported(imported, filename: url.importedItemName)
        } catch FileImportError.unsupportedFormat {
            importMessage = String(localized: "import.error.unsupportedFormat")
            return 0
        } catch {
            importMessage = String(localized: "waypoints.importError")
            Logger.waypoints.error("Waypoint import failed: \(error, privacy: .private)")
            return 0
        }
    }

    @discardableResult
    func insertImported(
        _ imported: [GPXImportService.ImportedWaypoint],
        filename: String? = nil
    ) -> Int {
        guard let context = modelContext else { return 0 }
        guard !imported.isEmpty else {
            importMessage = String(localized: "waypoints.importError")
            return 0
        }
        var count = 0
        for (i, item) in imported.enumerated() {
            let name = ImportedName.resolve(
                embedded: item.name,
                filename: filename,
                index: i,
                total: imported.count
            )
            let wp = Waypoint(
                name: name,
                coordinates: [item.longitude, item.latitude],
                category: item.category,
                elevation: item.elevation,
                icon: item.icon,
                color: item.color
            )
            // Imported waypoints start hidden so a freshly imported file doesn't
            // suddenly clutter the map with pins. User opts in via the list.
            wp.isVisible = false
            context.insert(wp)
            count += 1
        }
        save("waypoint")
        loadWaypoints()
        importMessage = String(localized: "waypoints.importSuccess \(count)")
        return count
    }

    func clearCaches() async {
        await elevationService.clearCache()
    }
}
