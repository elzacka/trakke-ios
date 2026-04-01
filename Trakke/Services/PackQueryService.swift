import Foundation
import GRDB

protocol PackQuerying: Sendable {
    func entries(for theme: KnowledgeTheme, in bounds: ViewportBounds, limit: Int) async throws -> [KnowledgeEntry]
    func articles(for category: ArticleCategory?) async throws -> [KnowledgeArticle]
    func closeDatabase(for packId: String) async
    func closeAll() async
}

extension PackQuerying {
    func entries(for theme: KnowledgeTheme, in bounds: ViewportBounds) async throws -> [KnowledgeEntry] {
        try await entries(for: theme, in: bounds, limit: 500)
    }
}

// MARK: - Pack Query Service

actor PackQueryService: PackQuerying {
    private var openDatabases: [String: DatabaseQueue] = [:]
    private var accessOrder: [String] = []
    private static let maxOpenDatabases = 5
    private var cachedInstalledPacks: [InstalledPackInfo]?
    private var cachedInstalledPacksAt: Date?
    private static let installedPacksCacheTTL: TimeInterval = 30

    // MARK: - Viewport Query

    func entries(
        for theme: KnowledgeTheme,
        in bounds: ViewportBounds,
        limit: Int = 500
    ) async throws -> [KnowledgeEntry] {
        let packIds = installedPackIds(for: theme)
        guard !packIds.isEmpty else { return [] }

        var results: [KnowledgeEntry] = []

        for packId in packIds {
            guard let db = try openDatabase(for: packId) else { continue }

            let entries = try await db.read { db in
                return try KnowledgeEntry.fetchAll(db, sql: """
                    SELECT e.* FROM entries e
                    JOIN entries_spatial s ON e.id = s.id
                    WHERE s.min_lat >= ? AND s.max_lat <= ?
                      AND s.min_lon >= ? AND s.max_lon <= ?
                      AND e.theme = ?
                    LIMIT ?
                    """,
                    arguments: [
                        bounds.south, bounds.north,
                        bounds.west, bounds.east,
                        theme.rawValue,
                        limit
                    ]
                )
            }

            results.append(contentsOf: entries)

            if results.count >= limit {
                return Array(results.prefix(limit))
            }
        }

        return results
    }

    // MARK: - Articles

    func articles(for category: ArticleCategory? = nil) async throws -> [KnowledgeArticle] {
        let packIds = allInstalledPackIds()
        var results: [KnowledgeArticle] = []

        for packId in packIds {
            guard let db = try openDatabase(for: packId) else { continue }

            let articles: [KnowledgeArticle]
            if let category {
                articles = try await db.read { db in
                    guard try db.tableExists("articles") else { return [] }
                    return try KnowledgeArticle.fetchAll(
                        db,
                        sql: "SELECT * FROM articles WHERE category = ? ORDER BY sort_order, title",
                        arguments: [category.rawValue]
                    )
                }
            } else {
                articles = try await db.read { db in
                    guard try db.tableExists("articles") else { return [] }
                    return try KnowledgeArticle.fetchAll(
                        db,
                        sql: "SELECT * FROM articles ORDER BY category, sort_order, title"
                    )
                }
            }

            results.append(contentsOf: articles)
        }

        return results
    }

    // MARK: - Lifecycle

    func closeAll() {
        openDatabases.removeAll()
        accessOrder.removeAll()
        cachedInstalledPacks = nil
        cachedInstalledPacksAt = nil
    }

    func closeDatabase(for packId: String) {
        openDatabases.removeValue(forKey: packId)
        accessOrder.removeAll { $0 == packId }
    }

    // MARK: - Private

    private func openDatabase(for packId: String) throws -> DatabaseQueue? {
        // Return cached connection
        if let db = openDatabases[packId] {
            touchAccess(packId)
            return db
        }

        // Evict LRU if at capacity
        if openDatabases.count >= Self.maxOpenDatabases, let lru = accessOrder.first {
            openDatabases.removeValue(forKey: lru)
            accessOrder.removeFirst()
        }

        // Open as immutable to prevent WAL/SHM file access (pre-built databases)
        let fileURL = PackStorageHelper.packFileURL(for: packId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        var config = Configuration()
        config.readonly = true
        config.label = "knowledge-\(packId)"

        // Use URI with immutable=1 so SQLite skips WAL/SHM file access
        let uri = "file:\(fileURL.path)?immutable=1"
        let db = try DatabaseQueue(path: uri, configuration: config)
        openDatabases[packId] = db
        accessOrder.append(packId)
        return db
    }

    private func touchAccess(_ packId: String) {
        accessOrder.removeAll { $0 == packId }
        accessOrder.append(packId)
    }

    private func loadInstalledPacksCached() -> [InstalledPackInfo] {
        if let cached = cachedInstalledPacks,
           let cachedAt = cachedInstalledPacksAt,
           Date().timeIntervalSince(cachedAt) < Self.installedPacksCacheTTL {
            return cached
        }
        let url = PackStorageHelper.installedPacksURL
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let packs = (try? decoder.decode([InstalledPackInfo].self, from: data)) ?? []
        cachedInstalledPacks = packs
        cachedInstalledPacksAt = Date()
        return packs
    }

    private func installedPackIds(for theme: KnowledgeTheme) -> [String] {
        loadInstalledPacksCached()
            .filter { $0.theme == theme.rawValue }
            .map(\.id)
    }

    private func allInstalledPackIds() -> [String] {
        loadInstalledPacksCached().map(\.id)
    }
}
