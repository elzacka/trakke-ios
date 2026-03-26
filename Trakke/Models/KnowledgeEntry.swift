import Foundation
import CoreLocation
import GRDB

// MARK: - Knowledge Entry

struct KnowledgeEntry: Identifiable, Sendable, Equatable {
    let id: Int64
    let externalId: String?
    let theme: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let geometry: String?
    let source: String
    let sourceURL: String?
    let attributes: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var knowledgeTheme: KnowledgeTheme? {
        KnowledgeTheme(rawValue: theme)
    }

    /// Decode the attributes JSON blob into a dictionary
    var attributesDictionary: [String: String] {
        guard let attributes, let data = attributes.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict.compactMapValues { value in
            if let string = value as? String { return string }
            if let number = value as? NSNumber { return number.stringValue }
            return nil
        }
    }

    static func == (lhs: KnowledgeEntry, rhs: KnowledgeEntry) -> Bool {
        lhs.id == rhs.id && lhs.theme == rhs.theme
    }
}

// MARK: - GRDB FetchableRecord

extension KnowledgeEntry: FetchableRecord {
    init(row: Row) {
        id = row["id"]
        externalId = row["external_id"]
        theme = row["theme"]
        name = row["name"]
        description = row["description"]
        latitude = row["lat"]
        longitude = row["lon"]
        geometry = row["geometry"]
        source = row["source"]
        sourceURL = row["source_url"]
        attributes = row["attributes"]
    }
}
