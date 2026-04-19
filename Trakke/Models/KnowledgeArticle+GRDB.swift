import Foundation
import GRDB

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
        verifiedAt = (try? Date(dateString, strategy: .iso8601)) ?? Date()
        sortOrder = row["sort_order"]
    }
}
