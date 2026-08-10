import SwiftUI
import CoreLocation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [SearchResult] = []
    var isSearching = false
    var error: String?
    var selectedResult: SearchResult?
    private var coordinateFormat: CoordinateFormat {
        let raw = UserDefaults.standard.string(forKey: AppStorageKeys.coordinateFormat) ?? ""
        return CoordinateFormat(rawValue: raw) ?? .dd
    }

    private let searchService: SearchService
    private var searchTask: Task<Void, Never>?

    /// Set once at app launch (see `AppLifecycleModifier`). Weak because the
    /// monitor is owned by `ContentView` for the whole app lifetime; if it is
    /// somehow nil we fall back to the network path's own timeout handling.
    private weak var connectivityMonitor: ConnectivityMonitor?

    init(searchService: SearchService = SearchService()) {
        self.searchService = searchService
    }

    func setConnectivityMonitor(_ monitor: ConnectivityMonitor) {
        connectivityMonitor = monitor
    }
    private static let debounceInterval: Duration = .milliseconds(300)

    func updateQuery(_ newQuery: String) {
        query = newQuery
        searchTask?.cancel()
        error = nil

        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        let service = searchService
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled, let self else { return }

            // Check for coordinate input first -- this works fully offline.
            if let coordResult = CoordinateService.parse(trimmed, preferredFormat: coordinateFormat) {
                results = [coordResult]
                isSearching = false
                return
            }

            // A place/address search hits the network. If we already know we
            // are offline, fail fast instead of waiting out APIClient's
            // waitsForConnectivity timeout (up to 60 s of spinner).
            if connectivityMonitor?.isConnected == false {
                results = []
                error = String(localized: "search.offline")
                isSearching = false
                return
            }

            do {
                let searchResults = try await service.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = searchResults
                error = nil
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                self.error = String(localized: "search.error")
            }
            isSearching = false
        }
    }

    func clearSearch() {
        query = ""
        results = []
        isSearching = false
        error = nil
        selectedResult = nil
        searchTask?.cancel()
    }

    func clearCaches() async {
        await searchService.clearCache()
    }


}
