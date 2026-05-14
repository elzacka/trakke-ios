import Foundation
import SwiftData

// versionIdentifier (1, 1, 0) is locked: this schema is deployed in the v1.0.0
// store of every shipped build. Changing it now would invalidate the migration
// metadata on every existing device and break lightweight migration. The
// asymmetric value (other versions use major.0.0) is intentional historical
// baggage from when V2 was first cut as a "1.1" patch over V1.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [Route.self, Waypoint.self]
    }
}
