import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Route.self, Waypoint.self, SchemaV1Project.self, SchemaV1DownloadedArea.self]
    }
}

// MARK: - Removed Models (inlined for migration support)

@Model
final class SchemaV1Project {
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

@Model
final class SchemaV1DownloadedArea {
    @Attribute(.unique) var id: String
    var name: String
    var bounds: [Double]
    var minZoom: Int
    var maxZoom: Int
    var layer: String
    var tileCount: Int
    var sizeBytes: Int64
    var downloadedAt: Date

    init(
        name: String,
        bounds: [Double],
        minZoom: Int,
        maxZoom: Int,
        layer: String,
        tileCount: Int,
        sizeBytes: Int64
    ) {
        self.id = "dl-\(Int(Date().timeIntervalSince1970))-\(String(Int.random(in: 0...999999), radix: 36))"
        self.name = name
        self.bounds = bounds
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.layer = layer
        self.tileCount = tileCount
        self.sizeBytes = sizeBytes
        self.downloadedAt = Date()
    }
}
