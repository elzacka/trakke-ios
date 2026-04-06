import Foundation

protocol PackCatalogFetching: Sendable {
    func fetchCatalog(forceRefresh: Bool) async throws -> PackCatalog
    func clearCache() async
}

extension PackCatalogFetching {
    func fetchCatalog() async throws -> PackCatalog {
        try await fetchCatalog(forceRefresh: false)
    }
}

// MARK: - Pack Catalog Service

actor PackCatalogService: PackCatalogFetching {
    private var cachedCatalog: PackCatalog?
    private var cachedAt: Date?
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    static let catalogURL = URL(string: "https://github.com/elzacka/trakke-ios/releases/download/knowledge-v3/catalog.json")!

    /// Current schema version supported by this app version
    static let supportedSchemaVersion = 1

    // MARK: - Public API

    func fetchCatalog(forceRefresh: Bool = false) async throws -> PackCatalog {
        // Return cached catalog if valid
        if !forceRefresh,
           let cached = cachedCatalog,
           let cachedAt,
           Date().timeIntervalSince(cachedAt) < Self.cacheTTL {
            return cached
        }

        // Try to fetch from network
        do {
            let data = try await APIClient.fetchData(url: Self.catalogURL, optional: true)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let catalog = try decoder.decode(PackCatalog.self, from: data)

            // Filter packs to only those this app version can read
            let compatibleCatalog = PackCatalog(
                version: catalog.version,
                generatedAt: catalog.generatedAt,
                packs: catalog.packs.filter { $0.minSchemaVersion <= Self.supportedSchemaVersion }
            )

            cachedCatalog = compatibleCatalog
            cachedAt = Date()

            // Persist catalog to disk for offline access
            try? persistCatalog(data)

            return compatibleCatalog
        } catch {
            // Fall back to cached catalog (in-memory or on-disk)
            if let cached = cachedCatalog {
                return cached
            }
            if let diskCatalog = loadPersistedCatalog() {
                cachedCatalog = diskCatalog
                cachedAt = Date()
                return diskCatalog
            }
            throw error
        }
    }

    /// Return the cached catalog without network access
    func cachedCatalogSync() -> PackCatalog? {
        if let cached = cachedCatalog { return cached }
        return loadPersistedCatalog()
    }

    func clearCache() {
        cachedCatalog = nil
        cachedAt = nil
        try? FileManager.default.removeItem(at: Self.catalogFileURL)
    }

    // MARK: - Disk Persistence

    private static var catalogFileURL: URL {
        PackStorageHelper.packsDirectory.appendingPathComponent("catalog.json")
    }

    private func persistCatalog(_ data: Data) throws {
        PackStorageHelper.ensureDirectoryExists()
        try data.write(to: Self.catalogFileURL, options: [.atomic, .completeFileProtection])
    }

    private func loadPersistedCatalog() -> PackCatalog? {
        guard let data = try? Data(contentsOf: Self.catalogFileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let catalog = try? decoder.decode(PackCatalog.self, from: data) else { return nil }
        return PackCatalog(
            version: catalog.version,
            generatedAt: catalog.generatedAt,
            packs: catalog.packs.filter { $0.minSchemaVersion <= Self.supportedSchemaVersion }
        )
    }
}

// MARK: - Pack Storage Helper

enum PackStorageHelper {
    static var packsDirectory: URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("KnowledgePacks")
        }
        return appSupport.appendingPathComponent("KnowledgePacks")
    }

    static func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: packsDirectory.path) {
            try? fm.createDirectory(at: packsDirectory, withIntermediateDirectories: true)
        }
        try? fm.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: packsDirectory.path
        )
    }

    static func packFileURL(for packId: String) -> URL {
        let sanitizedId = sanitize(packId)
        return packsDirectory.appendingPathComponent("\(sanitizedId).sqlite")
    }

    static func metadataFileURL(for packId: String) -> URL {
        let sanitizedId = sanitize(packId)
        return packsDirectory.appendingPathComponent("\(sanitizedId).meta.json")
    }

    /// Allowlist sanitization: only alphanumerics, hyphens, and underscores are kept.
    /// Prevents path traversal via `..`, `/`, null bytes, or other special characters.
    private static func sanitize(_ packId: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = packId.unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    static var installedPacksURL: URL {
        packsDirectory.appendingPathComponent("installed_packs.json")
    }
}
