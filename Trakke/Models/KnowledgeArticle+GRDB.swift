import Foundation
import GRDB

extension KnowledgeArticle: FetchableRecord {
    init(row: Row) {
        id = (row["id"] as Int64?) ?? 0
        theme = (row["theme"] as String?) ?? ""
        category = (row["category"] as String?) ?? ""
        title = (row["title"] as String?) ?? ""
        body = (row["body"] as String?) ?? ""
        source = (row["source"] as String?) ?? ""
        sourceURL = row["source_url"]
        let dateString: String = (row["verified_at"] as String?) ?? ""
        verifiedAt = (try? Date(dateString, strategy: .iso8601)) ?? Date()
        sortOrder = (row["sort_order"] as Int?) ?? 0
    }
}
