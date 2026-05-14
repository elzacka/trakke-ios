import Foundation
import SwiftData

enum TrakkeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [v1toV2, v2toV3, v3toV4, v4toV5]
    }

    // V1 -> V2: Remove unused Project and DownloadedArea models.
    // These were scaffolded in v1.0.0 but never populated.
    // Lightweight migration handles table deletion automatically.
    static let v1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    // V2 -> V3: Add Activity model for activity tracking.
    static let v2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    // V3 -> V4: Add `isVisible` to both Activity and Route so users can toggle
    // rendering of recorded/imported activities and routes on the map. Existing
    // rows default to true (visible) via the model's stored default values.
    static let v3toV4 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )

    // V4 -> V5: Add optional `category` to Route and Activity so users can
    // group them in the list, mirroring the existing Waypoint.category pattern.
    // Existing rows default to nil (lands in "Ukategorisert" group).
    static let v4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )
}
