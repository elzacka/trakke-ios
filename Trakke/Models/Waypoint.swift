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
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        coordinates: [Double],
        category: String? = nil,
        icon: String? = nil,
        color: String? = nil
    ) {
        self.id = "wp-\(Int(Date().timeIntervalSince1970))-\(String(Int.random(in: 0...999999), radix: 36))"
        self.name = name
        self.coordinates = coordinates
        self.category = category
        self.icon = icon
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
