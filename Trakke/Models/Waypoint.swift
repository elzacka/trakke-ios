import Foundation
import SwiftData

@Model
final class Waypoint {
    @Attribute(.unique) var id: String
    var name: String
    var coordinates: [Double]
    var category: String?
    var elevation: Double?
    var icon: String?
    var color: String?
    var isVisible: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        coordinates: [Double],
        category: String? = nil,
        elevation: Double? = nil,
        icon: String? = nil,
        color: String? = nil
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.coordinates = coordinates
        self.category = category
        self.elevation = elevation
        self.icon = icon
        self.color = color
        self.isVisible = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
