import Foundation
import SwiftData

enum SchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Route.self, Waypoint.self, Activity.self]
    }
}
