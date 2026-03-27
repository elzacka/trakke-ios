import Foundation
import GRDB

// MARK: - Article Category

enum ArticleCategory: String, CaseIterable, Identifiable, Sendable {
    case dyr
    case forstehjelp
    case giftigeArter
    case ly
    case mat
    case orientering
    case rettigheter
    case signalering
    case vann
    case varme

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vann: return String(localized: "knowledge.article.vann")
        case .mat: return String(localized: "knowledge.article.mat")
        case .giftigeArter: return String(localized: "knowledge.article.giftigeArter")
        case .varme: return String(localized: "knowledge.article.varme")
        case .ly: return String(localized: "knowledge.article.ly")
        case .orientering: return String(localized: "knowledge.article.orientering")
        case .forstehjelp: return String(localized: "knowledge.article.forstehjelp")
        case .signalering: return String(localized: "knowledge.article.signalering")
        case .dyr: return String(localized: "knowledge.article.dyr")
        case .rettigheter: return String(localized: "knowledge.article.rettigheter")
        }
    }

    var iconName: String {
        switch self {
        case .vann: return "drop.fill"
        case .mat: return "leaf.fill"
        case .giftigeArter: return "exclamationmark.octagon.fill"
        case .varme: return "flame.fill"
        case .ly: return "house.fill"
        case .orientering: return "safari.fill"
        case .forstehjelp: return "cross.case.fill"
        case .signalering: return "antenna.radiowaves.left.and.right"
        case .dyr: return "pawprint.fill"
        case .rettigheter: return "scale.3d"
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

// MARK: - GRDB FetchableRecord

extension KnowledgeArticle: FetchableRecord {
    init(row: Row) {
        id = row["id"]
        theme = row["theme"]
        category = row["category"]
        title = row["title"]
        body = row["body"]
        source = row["source"]
        sourceURL = row["source_url"]
        let dateString: String = row["verified_at"]
        verifiedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        sortOrder = row["sort_order"]
    }
}
