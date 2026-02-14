import Foundation
import SwiftData

@Model
final class DownloadedArea {
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
