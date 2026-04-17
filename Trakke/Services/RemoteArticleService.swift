import Foundation
import OSLog
import RegexBuilder

// MARK: - Remote Article Service

/// Fetches Knowledge articles from a GitHub content repository.
/// Articles are cached locally and only re-downloaded when their checksum changes.
protocol RemoteArticleFetching: Sendable {
    func fetchUpdates() async
    func cachedArticles() async -> [KnowledgeArticle]
    func clearCache() async
}

actor RemoteArticleService: RemoteArticleFetching {
    private static let catalogURL = "https://raw.githubusercontent.com/elzacka/trakke-content/main/catalog.json"
    private static let rawBaseURL = "https://raw.githubusercontent.com/elzacka/trakke-content/main/"
    private static let cacheDir = "articles"

    private var catalog: RemoteCatalog?

    // MARK: - Fetch Updates

    func fetchUpdates() async {
        do {
            guard let url = URL(string: Self.catalogURL) else { return }
            let data = try await APIClient.fetchData(
                url: url,
                additionalHeaders: ["Cache-Control": "no-cache"],
                optional: true
            )

            let remoteCatalog = try JSONDecoder().decode(RemoteCatalog.self, from: data)
            var localChecksums = loadLocalChecksums()

            var downloadCount = 0
            for article in remoteCatalog.articles {
                if localChecksums[article.file] == article.checksum {
                    continue
                }
                if await downloadArticle(article) {
                    localChecksums[article.file] = article.checksum
                    downloadCount += 1
                }
            }

            // Remove locally cached articles that no longer exist in the catalog
            let remoteFiles = Set(remoteCatalog.articles.map { $0.file })
            removeOrphanedCache(keeping: remoteFiles, checksums: &localChecksums)

            // Save catalog and checksums in a single write each
            saveCatalog(remoteCatalog)
            saveChecksums(localChecksums)

            if downloadCount > 0 {
                Logger.knowledge.info("Downloaded \(downloadCount) updated articles")
            }
        } catch {
            Logger.knowledge.warning("Failed to fetch article updates: \(error.localizedDescription)")
        }
    }

    // MARK: - Cached Articles

    func cachedArticles() -> [KnowledgeArticle] {
        guard let catalog = loadCatalog() else { return [] }

        var articles: [KnowledgeArticle] = []
        for entry in catalog.articles {
            let safeFile = Self.sanitizeFileName(entry.file)
            guard let body = readCachedArticleBody(safeFile) else { continue }
            articles.append(KnowledgeArticle(
                id: Int64(entry.id),
                theme: "remote",
                category: entry.category,
                title: entry.title,
                body: body,
                source: "",
                sourceURL: nil,
                verifiedAt: Date(),
                sortOrder: entry.sortOrder
            ))
        }
        return articles
    }

    func clearCache() {
        let dir = cacheDirectory()
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Private: Download

    private func downloadArticle(_ entry: CatalogEntry) async -> Bool {
        let safeFile = Self.sanitizeFileName(entry.file)
        guard !safeFile.isEmpty,
              let url = URL(string: Self.rawBaseURL + entry.file) else { return false }

        guard let data = try? await APIClient.fetchData(url: url, optional: true),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }

        let cacheFile = cacheDirectory().appendingPathComponent(safeFile)
        let dir = cacheFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: cacheFile, atomically: true, encoding: .utf8)

        return true
    }

    // MARK: - Private: Parse Article Body

    private func readCachedArticleBody(_ file: String) -> String? {
        let path = cacheDirectory().appendingPathComponent(file)
        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return nil }

        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 4 else { return nil }

        // Skip ## Category (line 0), blank (line 1), ### Title (line 2), blank (line 3)
        let bodyStart = min(4, lines.count)
        var body = lines[bodyStart...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert #### back to ## for in-app rendering
        body = body.replacingOccurrences(of: "\n#### ", with: "\n## ")
        if body.hasPrefix("#### ") {
            body = "## " + body.dropFirst(5)
        }

        return body
    }

    // MARK: - Private: File System

    private func cacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("Trakke/\(Self.cacheDir)")
    }

    private func checksumFile() -> URL {
        cacheDirectory().appendingPathComponent("checksums.json")
    }

    private func catalogFile() -> URL {
        cacheDirectory().appendingPathComponent("cached-catalog.json")
    }

    /// Strip path separators and limit to safe characters to prevent path traversal
    private static func sanitizeFileName(_ name: String) -> String {
        let base = name.components(separatedBy: "/").last ?? name
        return String(base.filter { $0.isLetter || $0.isNumber || "-_.".contains($0) }.prefix(120))
    }

    private func loadLocalChecksums() -> [String: String] {
        guard let data = try? Data(contentsOf: checksumFile()),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func saveChecksums(_ checksums: [String: String]) {
        if let data = try? JSONEncoder().encode(checksums) {
            let url = checksumFile()
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private func saveCatalog(_ catalog: RemoteCatalog) {
        if let data = try? JSONEncoder().encode(catalog) {
            let url = catalogFile()
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private func loadCatalog() -> RemoteCatalog? {
        guard let data = try? Data(contentsOf: catalogFile()) else { return nil }
        return try? JSONDecoder().decode(RemoteCatalog.self, from: data)
    }

    private func removeOrphanedCache(keeping remoteFiles: Set<String>, checksums: inout [String: String]) {
        for file in checksums.keys {
            if !remoteFiles.contains(file) {
                let safeName = Self.sanitizeFileName(file)
                let path = cacheDirectory().appendingPathComponent(safeName)
                try? FileManager.default.removeItem(at: path)
                checksums.removeValue(forKey: file)
            }
        }
    }
}

// MARK: - Catalog Models

private struct RemoteCatalog: Codable {
    let version: Int
    let generated: String
    let articles: [CatalogEntry]
}

private struct CatalogEntry: Codable {
    let id: Int
    let category: String
    let title: String
    let file: String
    let checksum: String
    let sortOrder: Int
}
