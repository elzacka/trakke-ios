import Foundation
import SwiftData

@Model
final class Route {
    @Attribute(.unique) var id: String
    var name: String
    var coordinates: [[Double]]
    var waypointIDs: [String]
    var distance: Double?
    var elevationGain: Double?
    var elevationLoss: Double?
    var difficulty: String?
    var color: String?
    /// Optional user-defined category for grouping in the route list (mirrors
    /// the Waypoint.category pattern). nil → "Ukategorisert" group.
    var category: String?
    var isVisible: Bool = false
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        coordinates: [[Double]] = [],
        waypointIDs: [String] = [],
        difficulty: String? = nil,
        color: String? = nil,
        category: String? = nil
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.coordinates = coordinates
        self.waypointIDs = waypointIDs
        self.difficulty = difficulty
        self.color = color
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
