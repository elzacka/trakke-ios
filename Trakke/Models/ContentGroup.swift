import Foundation

// MARK: - Content Group (shared by POI + Knowledge themes)

/// Groups map content by user intent, not data source.
/// Used by ExploreSheet to organize all toggleable map content.
enum ContentGroup: String, CaseIterable, Identifiable, Sendable {
    case beredskap
    case friluftsliv
    case kulturarv
    case landskap
    case naturOgVern

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beredskap: return String(localized: "explore.group.beredskap")
        case .friluftsliv: return String(localized: "explore.group.friluftsliv")
        case .naturOgVern: return String(localized: "explore.group.naturOgVern")
        case .kulturarv: return String(localized: "explore.group.kulturarv")
        case .landskap: return String(localized: "explore.group.landskap")
        }
    }

    var iconName: String {
        switch self {
        case .beredskap: return "shield.fill"
        case .friluftsliv: return "figure.hiking"
        case .naturOgVern: return "leaf.fill"
        case .kulturarv: return "building.columns.fill"
        case .landskap: return "mountain.2.fill"
        }
    }
}

// MARK: - Knowledge Theme

enum KnowledgeTheme: String, CaseIterable, Identifiable, Sendable {
    case kulturminnerLokaliteter
    case kulturmiljoer
    case naturvernomrader
    case restriksjonsomraderNaturvern
    case friluftslivsomrader
    case arterNasjonal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kulturminnerLokaliteter: return String(localized: "knowledge.theme.kulturminnerLokaliteter")
        case .kulturmiljoer: return String(localized: "knowledge.theme.kulturmiljoer")
        case .naturvernomrader: return String(localized: "knowledge.theme.naturvernomrader")
        case .restriksjonsomraderNaturvern: return String(localized: "knowledge.theme.restriksjonsomraderNaturvern")
        case .friluftslivsomrader: return String(localized: "knowledge.theme.friluftslivsomrader")
        case .arterNasjonal: return String(localized: "knowledge.theme.arterNasjonal")
        }
    }

    var iconName: String {
        switch self {
        case .kulturminnerLokaliteter: return "building.columns.fill"
        case .kulturmiljoer: return "map.fill"
        case .naturvernomrader: return "leaf.fill"
        case .restriksjonsomraderNaturvern: return "exclamationmark.triangle.fill"
        case .friluftslivsomrader: return "figure.hiking"
        case .arterNasjonal: return "pawprint.fill"
        }
    }

    var color: String {
        switch self {
        case .kulturminnerLokaliteter: return "#6b5b8a"
        case .kulturmiljoer: return "#7b6b9a"
        case .naturvernomrader: return "#2e7d32"
        case .restriksjonsomraderNaturvern: return "#c23a34"
        case .friluftslivsomrader: return "#558b2f"
        case .arterNasjonal: return "#4a7c8a"
        }
    }

    var minZoom: Double {
        switch self {
        case .kulturminnerLokaliteter: return 10
        case .kulturmiljoer: return 9
        case .naturvernomrader: return 8
        case .restriksjonsomraderNaturvern: return 9
        case .friluftslivsomrader: return 9
        case .arterNasjonal: return 10
        }
    }

    var sourceName: String {
        switch self {
        case .kulturminnerLokaliteter:
            return "Riksantikvaren"
        case .kulturmiljoer, .naturvernomrader, .restriksjonsomraderNaturvern,
             .friluftslivsomrader, .arterNasjonal:
            return String(localized: "knowledge.source.miljodirektoratet")
        }
    }

    var sourceLicense: String {
        "NLOD 2.0"
    }

    var contentGroup: ContentGroup {
        switch self {
        case .kulturminnerLokaliteter, .kulturmiljoer:
            return .kulturarv
        case .naturvernomrader, .restriksjonsomraderNaturvern, .arterNasjonal:
            return .naturOgVern
        case .friluftslivsomrader:
            return .friluftsliv
        }
    }

    /// Active themes available in the app
    static var phase1: [KnowledgeTheme] {
        [.kulturminnerLokaliteter, .kulturmiljoer, .naturvernomrader,
         .restriksjonsomraderNaturvern, .friluftslivsomrader, .arterNasjonal]
    }
}
