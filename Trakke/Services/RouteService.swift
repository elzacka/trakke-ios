import Foundation
import SwiftData
import CoreLocation

actor RouteService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    func fetchRoutes() throws -> [Route] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    @MainActor
    func fetchWaypoints() throws -> [Waypoint] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Waypoint>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    @MainActor
    func saveRoute(_ route: Route) throws {
        let context = modelContainer.mainContext
        context.insert(route)
        try context.save()
    }

    @MainActor
    func deleteRoute(_ route: Route) throws {
        let context = modelContainer.mainContext
        context.delete(route)
        try context.save()
    }

    @MainActor
    func saveWaypoint(_ waypoint: Waypoint) throws {
        let context = modelContainer.mainContext
        context.insert(waypoint)
        try context.save()
    }

    @MainActor
    func deleteWaypoint(_ waypoint: Waypoint) throws {
        let context = modelContainer.mainContext
        context.delete(waypoint)
        try context.save()
    }

    static func calculateDistance(coordinates: [[Double]]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<coordinates.count {
            guard coordinates[i - 1].count >= 2, coordinates[i].count >= 2 else { continue }
            let c1 = CLLocationCoordinate2D(latitude: coordinates[i - 1][1], longitude: coordinates[i - 1][0])
            let c2 = CLLocationCoordinate2D(latitude: coordinates[i][1], longitude: coordinates[i][0])
            total += Haversine.distance(from: c1, to: c2)
        }
        return total
    }
}
