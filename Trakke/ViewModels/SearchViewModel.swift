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

    private let searchService = SearchService()
    private var searchTask: Task<Void, Never>?
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
        searchTask = Task {
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }

            // Check for coordinate input first
            if let coordResult = CoordinateService.parse(trimmed) {
                self.results = [coordResult]
                self.isSearching = false
                return
            }

            do {
                let searchResults = try await service.search(query: trimmed)
                guard !Task.isCancelled else { return }
                self.results = searchResults
                self.error = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.results = []
                self.error = String(localized: "search.error")
            }
            self.isSearching = false
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

    func formattedCoordinate(for coordinate: CLLocationCoordinate2D) -> String {
        CoordinateService.format(coordinate: coordinate, format: coordinateFormat).display
    }
}
