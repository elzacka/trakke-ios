import SwiftUI
import SwiftData
import CoreLocation
import OSLog

@MainActor
@Observable
final class RouteViewModel {
    var routes: [Route] = []
    var selectedRoute: Route?
    var isDrawing = false
    var drawingCoordinates: [CLLocationCoordinate2D] = []
    var elevationProfile: [ElevationPoint] = []
    var elevationStats: ElevationStats?
    var isLoadingElevation = false
    var saveError: String?

    static let routeColors = Color.Trakke.routeColors

    private var modelContext: ModelContext?
    private let elevationService = ElevationService()

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    private func save(_ operation: String) {
        do {
            try modelContext?.save()
        } catch {
            Logger.routes.error("Failed to save (\(operation)): \(error, privacy: .private)")
            saveError = String(localized: "error.saveFailed")
        }
    }

    // MARK: - CRUD

    func loadRoutes() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        routes = (try? context.fetch(descriptor)) ?? []
    }

    func deleteRoute(_ route: Route) {
        guard let context = modelContext else { return }
        context.delete(route)
        save("delete route")
        loadRoutes()
    }

    func toggleVisibility(_ route: Route) {
        route.isVisible.toggle()
        route.updatedAt = Date()
        save("toggle visibility")
        loadRoutes()
    }

    // MARK: - Bulk visibility

    /// Show only this route — hide everything else of the same type.
    /// One SwiftData transaction so the map redraws once.
    func showOnly(_ route: Route) {
        let now = Date()
        for r in routes where r.id != route.id && r.isVisible {
            r.isVisible = false
            r.updatedAt = now
        }
        if !route.isVisible {
            route.isVisible = true
            route.updatedAt = now
        }
        save("show only route")
        loadRoutes()
    }

    func setAllVisible(_ visible: Bool) {
        let now = Date()
        for r in routes where r.isVisible != visible {
            r.isVisible = visible
            r.updatedAt = now
        }
        save("set all routes visible")
        loadRoutes()
    }

    func setCategoryVisibility(_ category: String?, visible: Bool) {
        let items = category.map { routes(for: $0) } ?? uncategorizedRoutes
        let now = Date()
        for r in items where r.isVisible != visible {
            r.isVisible = visible
            r.updatedAt = now
        }
        save("set route category visibility")
        loadRoutes()
    }

    func isCategoryAllVisible(_ category: String?) -> Bool {
        let items = category.map { routes(for: $0) } ?? uncategorizedRoutes
        return !items.isEmpty && items.allSatisfy(\.isVisible)
    }

    var isAnyVisible: Bool {
        routes.contains(where: \.isVisible)
    }

    func rename(_ route: Route, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != route.name else { return }
        route.name = trimmed
        route.updatedAt = Date()
        save("rename route")
        loadRoutes()
    }

    /// Edit name and/or category in one go. Empty name keeps the previous name;
    /// empty category clears categorisation (row falls into "Ukategorisert").
    func edit(_ route: Route, name: String, category: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { route.name = trimmedName }
        route.category = trimmedCategory.isEmpty ? nil : trimmedCategory
        route.updatedAt = Date()
        save("edit route")
        loadRoutes()
    }

    /// All distinct, non-empty categories in alphabetical order. Mirrors the
    /// `WaypointViewModel.categories` API so list views can group consistently.
    var categories: [String] {
        let raw = routes.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(raw)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func routes(for category: String) -> [Route] {
        routes.filter { $0.category == category }
    }

    var uncategorizedRoutes: [Route] {
        routes.filter { $0.category?.isEmpty != false }
    }

    var visibleRoutes: [Route] {
        routes.filter(\.isVisible)
    }

    func selectRoute(_ route: Route) {
        selectedRoute = route
        loadElevationProfile(for: route)
    }

    func clearSelection() {
        selectedRoute = nil
        elevationProfile = []
        elevationStats = nil
    }

    // MARK: - Drawing Distance

    var drawingDistance: Double {
        Haversine.totalDistance(coordinates: drawingCoordinates)
    }

    var formattedDrawingDistance: String {
        formattedDistance(drawingDistance)
    }

    // MARK: - Drawing

    func startDrawing() {
        isDrawing = true
        drawingCoordinates = []
    }

    func addPoint(_ coordinate: CLLocationCoordinate2D) {
        guard isDrawing else { return }
        drawingCoordinates.append(coordinate)
    }

    func undoLastPoint() {
        guard isDrawing, !drawingCoordinates.isEmpty else { return }
        drawingCoordinates.removeLast()
    }

    func movePoint(at index: Int, to coordinate: CLLocationCoordinate2D) {
        guard drawingCoordinates.indices.contains(index) else { return }
        drawingCoordinates[index] = coordinate
    }

    func cancelDrawing() {
        isDrawing = false
        drawingCoordinates = []
    }

    func finishDrawing(name: String, color: String? = nil) {
        guard let context = modelContext, drawingCoordinates.count >= 2 else { return }

        let coords = drawingCoordinates.map { [$0.longitude, $0.latitude] }
        let distance = Haversine.totalDistance(coordinates: coords)

        let route = Route(name: name)
        route.coordinates = coords
        route.distance = distance
        route.color = color ?? Self.routeColors[routes.count % Self.routeColors.count]

        context.insert(route)
        save("finish drawing")

        isDrawing = false
        drawingCoordinates = []
        loadRoutes()
    }

    // MARK: - Elevation

    func loadElevationProfile(for route: Route) {
        let coords = route.coordinates.compactMap { coord -> CLLocationCoordinate2D? in
            guard coord.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        guard coords.count >= 2 else { return }

        // If the route was imported from a file that carried per-point elevation,
        // build the profile locally instead of hitting the DEM service. This is
        // the only path that works offline AND respects data the user supplied.
        if let localProfile = Self.localElevationProfile(from: route.coordinates) {
            let stats = elevationService.calculateStats(from: localProfile)
            elevationProfile = localProfile
            elevationStats = stats
            return
        }

        isLoadingElevation = true
        let service = elevationService

        Task { [weak self] in
            guard let self else { return }
            do {
                let profile = try await service.fetchElevationProfile(coordinates: coords)
                let stats = service.calculateStats(from: profile)

                self.elevationProfile = profile
                self.elevationStats = stats

                // Update route with elevation data
                route.elevationGain = Double(stats.gain)
                route.elevationLoss = Double(stats.loss)
                route.updatedAt = Date()
                self.save("elevation data")
            } catch {
                Logger.routes.error("Elevation fetch error: \(error, privacy: .private)")
            }
            self.isLoadingElevation = false
        }
    }

    /// Build an `ElevationPoint` profile directly from route coordinates when
    /// each point carries elevation (3-tuple `[lon, lat, ele]`). Returns nil
    /// if any point lacks elevation — in which case the caller falls back to
    /// the DEM service.
    private static func localElevationProfile(from coordinates: [[Double]]) -> [ElevationPoint]? {
        guard coordinates.count >= 2 else { return nil }
        guard coordinates.allSatisfy({ $0.count >= 3 && $0[2].isFinite }) else { return nil }

        var cumulative: Double = 0
        var previous: CLLocationCoordinate2D?
        var points: [ElevationPoint] = []
        points.reserveCapacity(coordinates.count)
        for coord in coordinates {
            let here = CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            if let previous {
                cumulative += Haversine.distance(from: previous, to: here)
            }
            points.append(ElevationPoint(
                coordinate: here,
                elevation: coord[2],
                distance: cumulative
            ))
            previous = here
        }
        return points
    }

    /// Sum elevation gain and loss across coordinates when they have elevation.
    /// Returns nil when not all points carry an elevation value.
    static func elevationGainLoss(forCoordinates coordinates: [[Double]]) -> (gain: Double, loss: Double)? {
        guard coordinates.count >= 2 else { return nil }
        guard coordinates.allSatisfy({ $0.count >= 3 && $0[2].isFinite }) else { return nil }
        var gain: Double = 0
        var loss: Double = 0
        for i in 1..<coordinates.count {
            let diff = coordinates[i][2] - coordinates[i - 1][2]
            if diff > 0 { gain += diff } else { loss += -diff }
        }
        return (gain, loss)
    }

    // MARK: - Export

    func exportGPX(for route: Route) -> URL? {
        let gpxString = GPXExportService.exportRoute(route)
        let filename = GPXExportService.sanitizeFilename(route.name)
        return GPXExportService.writeToTemporaryFile(gpxString: gpxString, filename: filename)
    }

    // MARK: - Import

    var importMessage: String?
    var isImporting = false

    /// Detects file format from extension and routes to the appropriate parser.
    /// GPX and GeoJSON share the same `ImportedRoute` intermediate type so insertion
    /// is uniform regardless of source format.
    @discardableResult
    func importFile(from url: URL) -> Int {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "gpx":
            return importGPX(from: url)
        case "geojson", "json":
            return importGeoJSON(from: url)
        default:
            importMessage = String(localized: "import.error.unsupportedFormat")
            return 0
        }
    }

    /// Async variant used by the in-app file importer flow. Parses off the main
    /// actor so the UI can render the pending state (disabled button + progress).
    @discardableResult
    func importFileAsync(from url: URL) async -> Int {
        isImporting = true
        defer { isImporting = false }

        let ext = url.pathExtension.lowercased()
        switch ext {
        case "gpx":
            do {
                let imported = try await Task.detached(priority: .userInitiated) {
                    try GPXImportService.parseRoutes(from: url)
                }.value
                return insertImported(imported, filename: url.importedItemName)
            } catch {
                importMessage = String(localized: "routes.importError")
                Logger.routes.error("GPX route import failed: \(error, privacy: .private)")
                return 0
            }
        case "geojson", "json":
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try GeoJSONImportService.parse(from: url)
                }.value
                return insertImported(result.routes, filename: url.importedItemName)
            } catch {
                importMessage = String(localized: "routes.importError")
                Logger.routes.error("GeoJSON route import failed: \(error, privacy: .private)")
                return 0
            }
        default:
            importMessage = String(localized: "import.error.unsupportedFormat")
            return 0
        }
    }

    @discardableResult
    func importGPX(from url: URL) -> Int {
        do {
            let imported = try GPXImportService.parseRoutes(from: url)
            return insertImported(imported, filename: url.importedItemName)
        } catch {
            importMessage = String(localized: "routes.importError")
            Logger.routes.error("GPX route import failed: \(error, privacy: .private)")
            return 0
        }
    }

    @discardableResult
    func importGeoJSON(from url: URL) -> Int {
        do {
            let result = try GeoJSONImportService.parse(from: url)
            return insertImported(result.routes, filename: url.importedItemName)
        } catch {
            importMessage = String(localized: "routes.importError")
            Logger.routes.error("GeoJSON route import failed: \(error, privacy: .private)")
            return 0
        }
    }

    @discardableResult
    func insertImported(
        _ imported: [GPXImportService.ImportedRoute],
        filename: String? = nil
    ) -> Int {
        guard let context = modelContext else { return 0 }
        guard !imported.isEmpty else {
            importMessage = String(localized: "routes.importEmpty")
            return 0
        }
        for (i, importedRoute) in imported.enumerated() {
            let distance = Haversine.totalDistance(coordinates: importedRoute.coordinates)
            let name = ImportedName.resolve(
                embedded: importedRoute.name,
                filename: filename,
                index: i,
                total: imported.count
            )
            let route = Route(name: name)
            route.coordinates = importedRoute.coordinates
            route.distance = distance
            route.color = Self.routeColors[(routes.count + i) % Self.routeColors.count]
            // If the imported file carried per-point elevation, compute gain/loss
            // from it so the route list immediately shows the +Xm badge without
            // a DEM round-trip (which loadElevationProfile would otherwise do).
            if let (gain, loss) = Self.elevationGainLoss(forCoordinates: importedRoute.coordinates) {
                route.elevationGain = gain
                route.elevationLoss = loss
            }
            // Imported routes start hidden so a freshly imported file doesn't suddenly
            // clutter the map. The user opts in by toggling visibility from the list.
            route.isVisible = false
            context.insert(route)
        }
        do {
            try context.save()
        } catch {
            importMessage = String(localized: "routes.importError")
            Logger.routes.error("Route insert save failed: \(error, privacy: .private)")
            return 0
        }
        loadRoutes()
        let count = imported.count
        importMessage = String(localized: "routes.imported \(count)")
        return count
    }

    // MARK: - Distance Formatting

    func formattedDistance(_ meters: Double?) -> String {
        guard let meters, meters > 0 else { return "--" }
        return MeasurementService.formatDistance(meters)
    }

    func clearCaches() async {
        await elevationService.clearCache()
    }
}
