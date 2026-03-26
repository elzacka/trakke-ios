import Foundation
import SwiftData

enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Route.self, Waypoint.self, Activity.self]
    }
}
