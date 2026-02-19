import Foundation
import SwiftData

enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [Route.self, Waypoint.self]
    }
}
