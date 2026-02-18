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
    var isVisible: Bool = true
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        coordinates: [[Double]] = [],
        waypointIDs: [String] = [],
        difficulty: String? = nil,
        color: String? = nil
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.coordinates = coordinates
        self.waypointIDs = waypointIDs
        self.difficulty = difficulty
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
