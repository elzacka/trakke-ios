import SwiftUI
import SwiftData
import CoreLocation

@MainActor
@Observable
final class ActivityViewModel {
    private(set) var isRecording = false
    private(set) var currentDistance: Double = 0
    private(set) var currentElevationGain: Double = 0
    private(set) var currentDuration: TimeInterval = 0
    private(set) var activities: [Activity] = []
    var selectedActivity: Activity?
    var saveError: String?

    private let trackingService: any ActivityTracking
    private var statsTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    init(trackingService: any ActivityTracking = ActivityTrackingService()) {
        self.trackingService = trackingService
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    func loadActivities() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        activities = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        currentDistance = 0
        currentElevationGain = 0
        currentDuration = 0

        Task { [weak self] in
            await self?.trackingService.start()
        }

        statsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await self?.updateStats()
            }
        }
    }

    func processLocation(_ location: CLLocation) {
        guard isRecording else { return }
        Task { [weak self] in await self?.trackingService.addLocation(location) }
    }

    func stopAndSave(name: String) async {
        guard isRecording else { return }
        isRecording = false
        statsTask?.cancel()
        statsTask = nil

        let result = await trackingService.finish()

        guard let modelContext, result.trackPoints.count >= 2 else { return }

        let activity = Activity(
            name: name,
            trackPoints: result.trackPoints,
            distance: result.distance,
            elevationGain: result.elevationGain,
            elevationLoss: result.elevationLoss,
            duration: result.duration,
            startedAt: result.startedAt
        )
        activity.endedAt = result.endedAt

        modelContext.insert(activity)
        do {
            try modelContext.save()
            loadActivities()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func stopWithoutSaving() {
        guard isRecording else { return }
        isRecording = false
        statsTask?.cancel()
        statsTask = nil
        currentDistance = 0
        currentElevationGain = 0
        currentDuration = 0
        Task { [weak self] in
            await self?.trackingService.finish()
        }
    }

    func deleteActivity(_ activity: Activity) {
        guard let modelContext else { return }
        modelContext.delete(activity)
        do {
            try modelContext.save()
            loadActivities()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func deleteAllActivities() {
        guard let modelContext else { return }
        do {
            try modelContext.delete(model: Activity.self)
            try modelContext.save()
            loadActivities()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func exportGPX(for activity: Activity) -> URL? {
        let gpxString = GPXExportService.exportActivity(activity)
        let filename = GPXExportService.sanitizeFilename(activity.name)
        return GPXExportService.writeToTemporaryFile(gpxString: gpxString, filename: filename)
    }

    // MARK: - Import

    var importMessage: String?
    var isImporting = false

    @discardableResult
    func importFile(from url: URL) -> Int {
        do {
            let imported = try FileImporter.parse(
                from: url,
                gpx: GPXImportService.parseActivities,
                geoJSON: { try GeoJSONImportService.parse(from: $0).activities }
            )
            return insertImported(imported, filename: url.importedItemName)
        } catch FileImportError.unsupportedFormat {
            importMessage = String(localized: "import.error.unsupportedFormat")
            return 0
        } catch {
            importMessage = String(localized: "activity.importError")
            return 0
        }
    }

    /// Async variant used by the in-app file importer flow. Parses off the main
    /// actor so the UI can render the pending state.
    @discardableResult
    func importFileAsync(from url: URL) async -> Int {
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await FileImporter.parseOffActor(
                from: url,
                gpx: GPXImportService.parseActivities,
                geoJSON: { try GeoJSONImportService.parse(from: $0).activities }
            )
            return insertImported(imported, filename: url.importedItemName)
        } catch FileImportError.unsupportedFormat {
            importMessage = String(localized: "import.error.unsupportedFormat")
            return 0
        } catch {
            importMessage = String(localized: "activity.importError")
            return 0
        }
    }

    @discardableResult
    func insertImported(
        _ imported: [GPXImportService.ImportedActivity],
        filename: String? = nil
    ) -> Int {
        guard let modelContext else { return 0 }
        guard !imported.isEmpty else {
            importMessage = String(localized: "activity.importEmpty")
            return 0
        }
        var count = 0
        for (i, item) in imported.enumerated() {
            let name = ImportedName.resolve(
                embedded: item.name,
                filename: filename,
                index: i,
                total: imported.count
            )
            let activity = Activity(
                name: name,
                trackPoints: item.trackPoints,
                distance: Self.totalDistance(for: item.trackPoints),
                startedAt: item.startedAt
            )
            // Derive duration from first and last timestamps if available.
            if let first = item.trackPoints.first, first.count >= 4,
               let last = item.trackPoints.last, last.count >= 4 {
                activity.duration = max(0, last[3] - first[3])
                activity.endedAt = Date(timeIntervalSince1970: last[3])
            }
            // Elevation gain / loss from per-point elevation deltas.
            let (gain, loss) = Self.elevationGainLoss(for: item.trackPoints)
            activity.elevationGain = gain
            activity.elevationLoss = loss
            // Imported activities start hidden so the map doesn't suddenly fill
            // with old tracks. User opts in via the list's context menu.
            activity.isVisible = false
            modelContext.insert(activity)
            count += 1
        }
        do {
            try modelContext.save()
        } catch {
            importMessage = String(localized: "activity.importError")
            return 0
        }
        loadActivities()
        importMessage = String(localized: "activity.importSuccess \(count)")
        return count
    }

    // MARK: - Visibility and Conversion

    func toggleVisibility(_ activity: Activity) {
        activity.isVisible.toggle()
        do {
            try modelContext?.save()
        } catch {
            saveError = error.localizedDescription
        }
        loadActivities()
    }

    // MARK: - Bulk visibility (no `showOnly` — activities are historical, not
    // planning artefacts, so solo-isolating one trip has weak product meaning.)

    func setCategoryVisibility(_ category: String?, visible: Bool) {
        let items = category.map { activities(for: $0) } ?? uncategorizedActivities
        for activity in items where activity.isVisible != visible {
            activity.isVisible = visible
        }
        do {
            try modelContext?.save()
        } catch {
            saveError = error.localizedDescription
        }
        loadActivities()
    }

    func isCategoryAllVisible(_ category: String?) -> Bool {
        let items = category.map { activities(for: $0) } ?? uncategorizedActivities
        return !items.isEmpty && items.allSatisfy(\.isVisible)
    }

    func setAllVisible(_ visible: Bool) {
        for activity in activities where activity.isVisible != visible {
            activity.isVisible = visible
        }
        do {
            try modelContext?.save()
        } catch {
            saveError = error.localizedDescription
        }
        loadActivities()
    }

    var isAnyVisible: Bool {
        activities.contains(where: \.isVisible)
    }

    func rename(_ activity: Activity, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != activity.name else { return }
        activity.name = trimmed
        do {
            try modelContext?.save()
        } catch {
            saveError = error.localizedDescription
        }
        loadActivities()
    }

    /// Edit name and/or category in one go.
    func edit(_ activity: Activity, name: String, category: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { activity.name = trimmedName }
        activity.category = trimmedCategory.isEmpty ? nil : trimmedCategory
        do {
            try modelContext?.save()
        } catch {
            saveError = error.localizedDescription
        }
        loadActivities()
    }

    /// All distinct, non-empty categories in alphabetical order.
    var categories: [String] {
        let raw = activities.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(raw)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func activities(for category: String) -> [Activity] {
        activities.filter { $0.category == category }
    }

    var uncategorizedActivities: [Activity] {
        activities.filter { $0.category?.isEmpty != false }
    }

    /// Activities the user has opted to render on the map.
    var visibleActivities: [Activity] {
        activities.filter { $0.isVisible }
    }

    /// Converts an activity into a planned Route in the given route view model.
    /// Drops timestamps (a planned route is not a recording). Coordinates are
    /// preserved with their elevation when available.
    func convertToRoute(_ activity: Activity, using routeViewModel: RouteViewModel) {
        guard let modelContext else { return }
        let coords = activity.trackPoints.compactMap { point -> [Double]? in
            guard point.count >= 2 else { return nil }
            let lon = point[0]
            let lat = point[1]
            guard lon.isFinite, lat.isFinite else { return nil }
            return [lon, lat]
        }
        guard coords.count >= 2 else { return }
        let route = Route(name: activity.name)
        route.coordinates = coords
        route.distance = activity.distance
        route.elevationGain = activity.elevationGain
        route.elevationLoss = activity.elevationLoss
        route.color = RouteViewModel.routeColors[routeViewModel.routes.count % RouteViewModel.routeColors.count]
        // Converted route is visible by default — the user explicitly chose to
        // promote this activity into a route, so they likely want to see it.
        route.isVisible = true
        modelContext.insert(route)
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
            return
        }
        routeViewModel.loadRoutes()
    }

    private static func totalDistance(for points: [[Double]]) -> Double {
        var total: Double = 0
        for i in 1..<points.count {
            guard points[i].count >= 2, points[i - 1].count >= 2 else { continue }
            let a = CLLocation(latitude: points[i - 1][1], longitude: points[i - 1][0])
            let b = CLLocation(latitude: points[i][1], longitude: points[i][0])
            total += b.distance(from: a)
        }
        return total
    }

    private static func elevationGainLoss(for points: [[Double]]) -> (gain: Double, loss: Double) {
        var gain: Double = 0
        var loss: Double = 0
        for i in 1..<points.count {
            guard points[i].count >= 3, points[i - 1].count >= 3 else { continue }
            let delta = points[i][2] - points[i - 1][2]
            if delta > 0 { gain += delta } else { loss -= delta }
        }
        return (gain, loss)
    }

    // MARK: - Formatting

    var formattedDistance: String {
        MeasurementService.formatDistance(currentDistance)
    }

    var formattedDuration: String {
        Self.formatDuration(currentDuration)
    }

    var formattedElevationGain: String {
        MeasurementService.formatElevation(currentElevationGain)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDistance(_ distance: Double) -> String {
        MeasurementService.formatDistance(distance)
    }

    // MARK: - Private

    private func updateStats() async {
        let stats = await trackingService.currentStats()
        currentDistance = stats.distance
        currentElevationGain = stats.elevationGain
        currentDuration = stats.duration
    }
}
