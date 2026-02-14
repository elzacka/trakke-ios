import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: String
    var name: String
    var routeIDs: [String]
    var waypointIDs: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        routeIDs: [String] = [],
        waypointIDs: [String] = []
    ) {
        self.id = "proj-\(Int(Date().timeIntervalSince1970))-\(String(Int.random(in: 0...999999), radix: 36))"
        self.name = name
        self.routeIDs = routeIDs
        self.waypointIDs = waypointIDs
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
