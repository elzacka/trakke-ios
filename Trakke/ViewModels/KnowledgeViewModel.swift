import SwiftUI
import OSLog

/// Kunnskapsartikler: bundlet i appen fra `SurvivalArticles.json`, med
/// valgfrie oppdateringer hentet fra GitHub via `RemoteArticleService`.
///
/// Fram til august 2026 hadde denne klassen et helt parallelt system for
/// nedlastbare GRDB/SQLite-«kunnskapspakker» med romlig indekserte kartpunkter
/// (kulturminner, naturvernområder m.fl.) – katalog, nedlasting, temabrytere,
/// alt sammen. Det systemet mistet inngangsdøren sin (samme skjebne som de
/// øvrige døde ark-tilstandene, se dev_only/CLAUDE.md) da «Mer»-menyen ble
/// bygget om til dagens fem faner, og sto igjen som kode uten noen konsument:
/// ingen visning leste `entries`, og pakkene kunne aldri installeres uten
/// nedlastingsskjermen. Fjernet i sin helhet i stedet for gjenopplivet, fordi
/// ingen kartlag noensinne ble bygget for å tegne dem.
@MainActor
@Observable
final class KnowledgeViewModel {
    // MARK: - Article State

    var articles: [KnowledgeArticle] = []

    // MARK: - Private

    private let remoteArticleService: RemoteArticleService
    private var remoteUpdateTask: Task<Void, Never>?

    init(remoteArticleService: RemoteArticleService = RemoteArticleService()) {
        self.remoteArticleService = remoteArticleService
    }

    // MARK: - Articles

    func loadArticles(category: ArticleCategory? = nil) async {
        // Load bundled articles (always available, no download required)
        var result = Self.loadBundledArticles()

        // Merge remote articles – remote overrides bundled by matching ID
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

    // MARK: - GDPR Data Deletion

    /// Alle service-protokoller definerer `clearCache()`, kalt fra
    /// `AppCoordinator.clearAllServiceCaches()`. Fjerner den lokale
    /// artikkel-cachen `RemoteArticleService` har lastet ned; de bundlede
    /// artiklene er del av appen selv og slettes ikke.
    func clearCache() {
        Task { [weak self] in
            guard let self else { return }
            await self.remoteArticleService.clearCache()
            self.articles = []
        }
    }
}
