import Foundation

// MARK: - Article Category

enum ArticleCategory: String, CaseIterable, Identifiable, Sendable {
    case beredskap
    case dyr
    case fjellvettreglene
    case forstehjelp
    case giftigeArter
    case ly
    case mat
    case mentaleStrategier
    case nodprosedyrer
    case orientering
    case rettigheter
    case utstyr
    case vaer
    case vann
    case varme

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vann: return String(localized: "knowledge.article.vann")
        case .mat: return String(localized: "knowledge.article.mat")
        case .beredskap: return String(localized: "knowledge.article.beredskap")
        case .fjellvettreglene: return String(localized: "knowledge.article.fjellvettreglene")
        case .giftigeArter: return String(localized: "knowledge.article.giftigeArter")
        case .varme: return String(localized: "knowledge.article.varme")
        case .ly: return String(localized: "knowledge.article.ly")
        case .mentaleStrategier: return String(localized: "knowledge.article.mentaleStrategier")
        case .orientering: return String(localized: "knowledge.article.orientering")
        case .forstehjelp: return String(localized: "knowledge.article.forstehjelp")
        case .nodprosedyrer: return String(localized: "knowledge.article.nodprosedyrer")
        case .utstyr: return String(localized: "knowledge.article.utstyr")
        case .vaer: return String(localized: "knowledge.article.vaer")
        case .dyr: return String(localized: "knowledge.article.dyr")
        case .rettigheter: return String(localized: "knowledge.article.rettigheter")
        }
    }

    var iconName: String? {
        switch self {
        case .vann: return "drop.fill"
        case .mat: return "leaf.fill"
        case .beredskap: return "shield.checkered"
        case .fjellvettreglene: return "mountain.2.fill"
        case .giftigeArter: return "exclamationmark.octagon.fill"
        case .varme: return "flame.fill"
        case .ly: return "house.fill"
        case .mentaleStrategier: return "brain.head.profile.fill"
        case .orientering: return "safari.fill"
        case .forstehjelp: return "cross.case.fill"
        case .nodprosedyrer: return "exclamationmark.triangle.fill"
        case .utstyr: return "wrench.and.screwdriver.fill"
        case .vaer: return "cloud.sun.fill"
        case .dyr: return "pawprint.fill"
        case .rettigheter: return nil
        }
    }

    /// Custom text glyph for categories without an SF Symbol (e.g. § for rettigheter)
    var iconGlyph: String? {
        switch self {
        case .rettigheter: return "§"
        default: return nil
        }
    }
}

// MARK: - Knowledge Article

struct KnowledgeArticle: Identifiable, Hashable, Sendable {
    let id: Int64
    let theme: String
    let category: String
    let title: String
    let body: String
    let source: String
    let sourceURL: String?
    let verifiedAt: Date
    let sortOrder: Int

    var articleCategory: ArticleCategory? {
        ArticleCategory(rawValue: category)
    }
}

