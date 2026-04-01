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
