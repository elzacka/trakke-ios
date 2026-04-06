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
    var coordinateFormat: CoordinateFormat = .dd

    private let searchService: any SearchFetching
    private var searchTask: Task<Void, Never>?

    init(searchService: any SearchFetching = SearchService()) {
        self.searchService = searchService
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

            // Check for coordinate input first
            if let coordResult = CoordinateService.parse(trimmed) {
                results = [coordResult]
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

    func selectResult(_ result: SearchResult) {
        selectedResult = result
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

    func formattedCoordinate(for coordinate: CLLocationCoordinate2D) -> String {
        CoordinateService.format(coordinate: coordinate, format: coordinateFormat).display
    }
}
