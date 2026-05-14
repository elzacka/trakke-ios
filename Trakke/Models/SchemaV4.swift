import Foundation
import SwiftData

enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Route.self, Waypoint.self, Activity.self]
    }
}
