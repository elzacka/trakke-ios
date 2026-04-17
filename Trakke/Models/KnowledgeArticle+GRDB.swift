import Foundation
import GRDB

extension KnowledgeArticle: FetchableRecord {
    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    init(row: Row) {
        id = row["id"]
        theme = row["theme"]
        category = row["category"]
        title = row["title"]
        body = row["body"]
        source = row["source"]
        sourceURL = row["source_url"]
        let dateString: String = row["verified_at"]
        verifiedAt = Self.dateFormatter.date(from: dateString) ?? Date()
        sortOrder = row["sort_order"]
    }
}
