import SwiftUI
import SwiftData
import CoreLocation
import os

private let logger = Logger(subsystem: "no.tazk.trakke", category: "RouteViewModel")

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

    // Route colors
    static let routeColors = [
        "#3e4533", "#e74c3c", "#3498db", "#2ecc71",
        "#f39c12", "#9b59b6", "#1abc9c", "#e67e22",
    ]

    private var modelContext: ModelContext?
    private let elevationService = ElevationService()

    func setModelContext(_ context: ModelContext) {
        modelContext = context
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
        do { try context.save() } catch { logger.error("Failed to save after deleting route: \(error, privacy: .private)") }
        loadRoutes()
    }

    func toggleVisibility(_ route: Route) {
        route.isVisible.toggle()
        route.updatedAt = Date()
        do { try modelContext?.save() } catch { logger.error("Failed to save route visibility: \(error, privacy: .private)") }
        loadRoutes()
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
        do { try context.save() } catch { logger.error("Failed to save new route: \(error, privacy: .private)") }

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

        isLoadingElevation = true
        let service = elevationService

        Task {
            do {
                let profile = try await service.fetchElevationProfile(coordinates: coords)
                let stats = await service.calculateStats(from: profile)

                self.elevationProfile = profile
                self.elevationStats = stats

                // Update route with elevation data
                route.elevationGain = Double(stats.gain)
                route.elevationLoss = Double(stats.loss)
                route.updatedAt = Date()
                do { try self.modelContext?.save() } catch { logger.error("Failed to save elevation data: \(error, privacy: .private)") }
            } catch {
                #if DEBUG
                print("Elevation fetch error: \(error)")
                #endif
            }
            self.isLoadingElevation = false
        }
    }

    // MARK: - GPX Export

    func exportGPX(for route: Route) -> URL? {
        let gpxString = GPXExportService.exportRoute(route)
        let filename = GPXExportService.sanitizeFilename(route.name)
        return GPXExportService.writeToTemporaryFile(gpxString: gpxString, filename: filename)
    }

    // MARK: - GPX Import

    var importMessage: String?

    func importGPX(from url: URL) {
        guard let context = modelContext else { return }
        do {
            let imported = try GPXImportService.parseRoutes(from: url)
            guard !imported.isEmpty else {
                importMessage = String(localized: "routes.importEmpty")
                return
            }
            for (i, importedRoute) in imported.enumerated() {
                let distance = Haversine.totalDistance(coordinates: importedRoute.coordinates)
                let route = Route(name: importedRoute.name)
                route.coordinates = importedRoute.coordinates
                route.distance = distance
                route.color = Self.routeColors[(routes.count + i) % Self.routeColors.count]
                context.insert(route)
            }
            try context.save()
            loadRoutes()
            let count = imported.count
            importMessage = String(localized: "routes.imported \(count)")
        } catch {
            importMessage = String(localized: "routes.importError")
            logger.error("GPX route import failed: \(error, privacy: .private)")
        }
    }

    // MARK: - Distance Formatting

    func formattedDistance(_ meters: Double?) -> String {
        guard let meters, meters > 0 else { return "--" }
        return MeasurementService.formatDistance(meters)
    }
}
