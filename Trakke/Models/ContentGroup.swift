import Foundation

// MARK: - Content Group

/// Groups map content by user intent, not data source. Used by
/// `CategoryHierarchyView` (Hjem-fanen) to organize POI-kategorier.
///
/// Delte tidligere navn med `KnowledgeTheme`, et parallelt nedlastbart
/// kartlag-system (kulturminner, naturvernområder m.fl.) som aldri fikk noen
/// konsument etter at «Mer»-menyen ble bygget om. `KnowledgeTheme` er fjernet;
/// `ContentGroup` lever videre alene siden POI-kategoriene fortsatt bruker den.
enum ContentGroup: String, CaseIterable, Identifiable, Sendable {
    case beredskap
    case ferdsel
    case friluftsliv
    case kulturarv
    case landskap
    case naturOgVern

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beredskap: return String(localized: "explore.group.beredskap")
        case .ferdsel: return String(localized: "explore.group.ferdsel")
        case .friluftsliv: return String(localized: "explore.group.friluftsliv")
        case .naturOgVern: return String(localized: "explore.group.naturOgVern")
        case .kulturarv: return String(localized: "explore.group.kulturarv")
        case .landskap: return String(localized: "explore.group.landskap")
        }
    }

    var iconName: String {
        switch self {
        case .beredskap: return "shield.fill"
        case .ferdsel: return "signpost.right.fill"
        case .friluftsliv: return "figure.hiking"
        case .naturOgVern: return "leaf.fill"
        case .kulturarv: return "building.columns.fill"
        case .landskap: return "mountain.2.fill"
        }
    }
}
