import SwiftUI
import CoreLocation
import OSLog

@MainActor
@Observable
final class KnowledgeViewModel {
    // MARK: - Catalog State

    var availablePacks: [KnowledgePack] = []
    var isLoadingCatalog = false
    var catalogError: String?
    var catalogLastUpdated: Date?

    // MARK: - Installed Packs

    var installedPacks: [InstalledPackInfo] = []

    // MARK: - Download State

    var activeDownloads: [String: DownloadProgress] = [:]

    // MARK: - Query State (map annotations)

    var enabledThemes: Set<KnowledgeTheme> = []
    var entries: [KnowledgeEntry] = []
    var selectedEntry: KnowledgeEntry?
    var isQuerying = false

    // MARK: - Article State

    var articles: [KnowledgeArticle] = []

    // MARK: - Private

    private let catalogService: any PackCatalogFetching
    private let downloadManager: any PackDownloading
    private let queryService: any PackQuerying
    private let remoteArticleService: any RemoteArticleFetching
    private var queryTask: Task<Void, Never>?
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var remoteUpdateTask: Task<Void, Never>?
    private var lastBounds: ViewportBounds?
    private var lastZoom: Double = 0
    private static let debounceInterval: Duration = .milliseconds(500)

    init(
        catalogService: any PackCatalogFetching = PackCatalogService(),
        downloadManager: any PackDownloading = PackDownloadManager(),
        queryService: any PackQuerying = PackQueryService(),
        remoteArticleService: any RemoteArticleFetching = RemoteArticleService()
    ) {
        self.catalogService = catalogService
        self.downloadManager = downloadManager
        self.queryService = queryService
        self.remoteArticleService = remoteArticleService
    }

    // MARK: - Catalog

    func loadCatalog() async {
        isLoadingCatalog = true
        catalogError = nil

        do {
            let catalog = try await catalogService.fetchCatalog()
            availablePacks = catalog.packs
            catalogLastUpdated = catalog.generatedAt
        } catch {
            catalogError = error.localizedDescription
            Logger.knowledge.error("Catalog fetch error: \(error, privacy: .private)")
        }

        isLoadingCatalog = false
    }

    func refreshCatalog() async {
        isLoadingCatalog = true
        catalogError = nil

        do {
            let catalog = try await catalogService.fetchCatalog(forceRefresh: true)
            availablePacks = catalog.packs
            catalogLastUpdated = catalog.generatedAt
        } catch {
            catalogError = error.localizedDescription
        }

        isLoadingCatalog = false
    }

    // MARK: - Downloads

    func downloadPack(_ pack: KnowledgePack) {
        let manager = downloadManager
        downloadTasks[pack.id] = Task { [weak self] in
            guard let self else { return }
            let progressStream = await manager.download(pack: pack)
            for await progress in progressStream {
                guard !Task.isCancelled else { return }
                activeDownloads[pack.id] = progress
                if progress.isComplete {
                    activeDownloads.removeValue(forKey: pack.id)
                    downloadTasks.removeValue(forKey: pack.id)
                    refreshInstalledPacks()

                    // If the theme is enabled, reload entries
                    if let theme = KnowledgeTheme(rawValue: pack.theme),
                       enabledThemes.contains(theme),
                       let bounds = lastBounds {
                        loadTheme(theme, bounds: bounds, zoom: lastZoom)
                    }
                }
            }
        }
    }

    func cancelDownload(packId: String) {
        downloadTasks[packId]?.cancel()
        downloadTasks.removeValue(forKey: packId)
        Task { [weak self] in
            guard let self else { return }
            await downloadManager.cancelDownload(packId: packId)
            activeDownloads.removeValue(forKey: packId)
        }
    }

    func deletePack(_ info: InstalledPackInfo) {
        Task { [weak self] in
            guard let self else { return }
            // Close database connection first
            await queryService.closeDatabase(for: info.id)
            try? await downloadManager.deletePack(packId: info.id)
            refreshInstalledPacks()

            // Reload entries if relevant theme is enabled
            if let theme = KnowledgeTheme(rawValue: info.theme),
               enabledThemes.contains(theme),
               let bounds = lastBounds {
                loadTheme(theme, bounds: bounds, zoom: lastZoom)
            }
        }
    }

    func deleteAllPacks() {
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
        Task { [weak self] in
            guard let self else { return }
            await queryService.closeAll()
            try? await downloadManager.deleteAllPacks()
            await catalogService.clearCache()
            await remoteArticleService.clearCache()
            installedPacks = []
            entries = []
            articles = []
            enabledThemes = []
            activeDownloads = [:]
        }
    }

    func refreshInstalledPacks() {
        Task { [weak self] in
            guard let self else { return }
            installedPacks = await downloadManager.installedPacks()
        }
    }

    // MARK: - Theme Toggles

    func toggleTheme(_ theme: KnowledgeTheme) {
        if enabledThemes.contains(theme) {
            enabledThemes.remove(theme)
            entries.removeAll { $0.theme == theme.rawValue }
        } else {
            enabledThemes.insert(theme)
            if let bounds = lastBounds {
                loadTheme(theme, bounds: bounds, zoom: lastZoom)
            }
        }
    }

    private func loadTheme(_ theme: KnowledgeTheme, bounds: ViewportBounds, zoom: Double) {
        let service = queryService
        Task { [weak self] in
            guard let self else { return }
            isQuerying = true
            do {
                let newEntries = try await service.entries(for: theme, in: bounds)
                guard enabledThemes.contains(theme) else {
                    isQuerying = false
                    return
                }
                entries.removeAll { $0.theme == theme.rawValue }
                entries.append(contentsOf: newEntries)
            } catch {
                Logger.knowledge.error("Knowledge query error (\(theme.rawValue, privacy: .public)): \(error, privacy: .private)")
            }
            isQuerying = false
        }
    }

    // MARK: - Viewport Queries

    func viewportChanged(bounds: ViewportBounds, zoom: Double) {
        lastBounds = bounds
        lastZoom = zoom

        guard !enabledThemes.isEmpty else { return }

        queryTask?.cancel()
        let service = queryService
        let themes = enabledThemes

        queryTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }

            self.isQuerying = true

            for theme in themes {
                guard !Task.isCancelled else { return }
                guard zoom >= theme.minZoom else {
                    self.entries.removeAll { $0.theme == theme.rawValue }
                    continue
                }

                do {
                    let result = try await service.entries(for: theme, in: bounds)
                    guard !Task.isCancelled else { return }
                    self.entries.removeAll { $0.theme == theme.rawValue }
                    self.entries.append(contentsOf: result)
                } catch {
                    guard !Task.isCancelled else { return }
                    Logger.knowledge.error("Knowledge viewport query error (\(theme.rawValue, privacy: .public)): \(error, privacy: .private)")
                }
            }

            // Remove entries for disabled themes
            self.entries.removeAll { entry in
                guard let theme = KnowledgeTheme(rawValue: entry.theme) else { return true }
                return !self.enabledThemes.contains(theme)
            }

            self.isQuerying = false
        }
    }

    // MARK: - Articles

    func loadArticles(category: ArticleCategory? = nil) async {
        // Load bundled articles (always available, no download required)
        var result = Self.loadBundledArticles()

        // Merge remote articles — remote overrides bundled by matching ID
        let remote = await remoteArticleService.cachedArticles()
        var seenIDs = Set<Int64>(result.map { $0.id })
        if !remote.isEmpty {
            let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            result = result.map { bundled in
                remoteByID[bundled.id] ?? bundled
            }
            for r in remote where !seenIDs.contains(r.id) {
                result.append(r)
                seenIDs.insert(r.id)
            }
        }

        // Also load articles from downloaded packs (skip IDs already present)
        do {
            let packArticles = try await queryService.articles(for: category)
            for article in packArticles where !seenIDs.contains(article.id) {
                result.append(article)
                seenIDs.insert(article.id)
            }
        } catch {
            Logger.knowledge.error("Pack article load error: \(error, privacy: .private)")
        }

        // Filter by category if requested
        if let category {
            result = result.filter { $0.category == category.rawValue }
        }

        articles = result.sorted { ($0.category, $0.sortOrder) < ($1.category, $1.sortOrder) }
    }

    func fetchRemoteArticleUpdates() {
        guard remoteUpdateTask == nil else { return }
        remoteUpdateTask = Task { [weak self] in
            guard let self else { return }
            await remoteArticleService.fetchUpdates()
            await loadArticles()
            remoteUpdateTask = nil
        }
    }

    // MARK: - Bundled Articles

    static func loadBundledArticles() -> [KnowledgeArticle] {
        guard let url = Bundle.main.url(forResource: "SurvivalArticles", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return [] }

        struct BundledArticle: Decodable {
            let id: Int64
            let category: String
            let title: String
            let body: String
            let source: String
            let sourceURL: String?
            let sortOrder: Int
        }

        let decoder = JSONDecoder()
        guard let bundled = try? decoder.decode([BundledArticle].self, from: data) else { return [] }

        return bundled.map { item in
            KnowledgeArticle(
                id: item.id,
                theme: "survival",
                category: item.category,
                title: item.title,
                body: item.body,
                source: item.source,
                sourceURL: item.sourceURL,
                verifiedAt: Date(),
                sortOrder: item.sortOrder
            )
        }
    }

    // MARK: - Selection

    func selectEntry(_ entry: KnowledgeEntry) {
        selectedEntry = entry
    }

    func clearSelection() {
        selectedEntry = nil
    }

    // MARK: - Helpers

    func isInstalled(packId: String) -> Bool {
        installedPacks.contains { $0.id == packId }
    }

    func isDownloading(packId: String) -> Bool {
        activeDownloads[packId] != nil
    }

    func packsForTheme(_ theme: KnowledgeTheme) -> [KnowledgePack] {
        availablePacks.filter { $0.theme == theme.rawValue }
    }

    var installedPacksSize: Int64 {
        installedPacks.reduce(0) { $0 + $1.fileSize }
    }
}
