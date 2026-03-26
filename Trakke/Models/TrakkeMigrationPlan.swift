import Foundation
import SwiftData

enum TrakkeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [v1toV2, v2toV3]
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
}
