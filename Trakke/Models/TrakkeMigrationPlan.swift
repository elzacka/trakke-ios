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

    // V2 -> V3: Add Activity model and the additive `isVisible` / optional
    // `category` columns on Route, Waypoint and Activity. All changes are
    // additive – SwiftData's lightweight migration handles them implicitly
    // when reading older V3 stores that lack these columns.
    //
    // Earlier work split this into intermediate V4 (isVisible) and V5
    // (category) schemas, but those schemas referenced the same @Model
    // types as V3 and therefore produced identical SwiftData checksums –
    // crashing at launch with "Duplicate version checksums detected".
    // Neither V4 nor V5 was ever distributed, so collapsing them into V3
    // is safe.
    static let v2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}
