import SwiftUI
import SwiftData
import CoreLocation

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

    private var modelContainer: ModelContainer?
    private let elevationService = ElevationService()

    func setModelContainer(_ container: ModelContainer) {
        modelContainer = container
    }

    // MARK: - CRUD

    func loadRoutes() {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        routes = (try? context.fetch(descriptor)) ?? []
    }

    func deleteRoute(_ route: Route) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        context.delete(route)
        try? context.save()
        loadRoutes()
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

    func cancelDrawing() {
        isDrawing = false
        drawingCoordinates = []
    }

    func finishDrawing(name: String, color: String? = nil) {
        guard let container = modelContainer, drawingCoordinates.count >= 2 else { return }

        let coords = drawingCoordinates.map { [$0.longitude, $0.latitude] }
        let distance = RouteService.calculateDistance(coordinates: coords)

        let route = Route(name: name)
        route.coordinates = coords
        route.distance = distance
        route.color = color ?? Self.routeColors[routes.count % Self.routeColors.count]

        let context = container.mainContext
        context.insert(route)
        try? context.save()

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
                try? self.modelContainer?.mainContext.save()
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

    // MARK: - Distance Formatting

    func formattedDistance(_ meters: Double?) -> String {
        guard let meters, meters > 0 else { return "--" }
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
