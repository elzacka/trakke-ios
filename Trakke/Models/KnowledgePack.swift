import Foundation

// MARK: - Knowledge Pack

struct KnowledgePack: Identifiable, Sendable, Codable {
    let id: String
    let name: String
    let theme: String
    let county: String?
    let downloadURL: URL
    let fileSize: Int64
    let entryCount: Int
    let schemaVersion: Int
    let minSchemaVersion: Int
    let generatedAt: Date
    let checksum: String

    enum CodingKeys: String, CodingKey {
        case id, name, theme, county
        case downloadURL = "download_url"
        case fileSize = "file_size"
        case entryCount = "entry_count"
        case schemaVersion = "schema_version"
        case minSchemaVersion = "min_schema_version"
        case generatedAt = "generated_at"
        case checksum
    }
}

// MARK: - County Display Name

private let countyNames: [String: String] = [
    "03": "Oslo",
    "11": "Rogaland",
    "15": "Møre og Romsdal",
    "18": "Nordland",
    "31": "Østfold",
    "32": "Akershus",
    "33": "Buskerud",
    "34": "Innlandet",
    "39": "Vestfold",
    "40": "Telemark",
    "42": "Agder",
    "46": "Vestland",
    "50": "Trøndelag",
    "55": "Troms",
    "56": "Finnmark",
]

extension KnowledgePack {
    /// County display name extracted from the pack name or county code
    var countyName: String {
        if let county, let name = countyNames[county] { return name }
        // Fallback: extract from pack name after " – "
        if let range = name.range(of: " – ") {
            return String(name[range.upperBound...])
        }
        return name
    }
}

extension InstalledPackInfo {
    /// County display name extracted from the pack name or county code
    var countyName: String {
        if let county, let name = countyNames[county] { return name }
        if let range = name.range(of: " – ") {
            return String(name[range.upperBound...])
        }
        return name
    }
}

// MARK: - Pack Catalog

struct PackCatalog: Sendable, Codable {
    let version: Int
    let generatedAt: Date
    let packs: [KnowledgePack]

    enum CodingKeys: String, CodingKey {
        case version
        case generatedAt = "generated_at"
        case packs
    }
}

// MARK: - Installed Pack Info

struct InstalledPackInfo: Identifiable, Sendable, Codable {
    let id: String
    let name: String
    let theme: String
    let county: String?
    let fileSize: Int64
    let entryCount: Int
    let installedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, theme, county
        case fileSize = "file_size"
        case entryCount = "entry_count"
        case installedAt = "installed_at"
    }
}

// MARK: - Download Progress

struct DownloadProgress: Sendable {
    let packId: String
    let bytesWritten: Int64
    let totalBytes: Int64
    let isComplete: Bool

    var percentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesWritten) / Double(totalBytes)
    }
}
