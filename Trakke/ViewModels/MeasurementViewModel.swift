import Foundation
import CoreLocation

enum MeasurementMode: String, Sendable {
    case distance
    case area
}

@MainActor
@Observable
final class MeasurementViewModel {
    var isActive = false
    var mode: MeasurementMode?
    var points: [CLLocationCoordinate2D] = []

    // MARK: - Computed

    var hasMinimumPoints: Bool {
        switch mode {
        case .distance: return points.count >= 2
        case .area: return points.count >= 3
        case nil: return false
        }
    }

    var formattedResult: String? {
        guard hasMinimumPoints else { return nil }

        switch mode {
        case .distance:
            let distance = MeasurementService.polylineDistance(points)
            return MeasurementService.formatDistance(distance)
        case .area:
            let area = MeasurementService.polygonArea(points)
            return MeasurementService.formatArea(area)
        case nil:
            return nil
        }
    }

    var rawResult: Double {
        switch mode {
        case .distance:
            return MeasurementService.polylineDistance(points)
        case .area:
            return MeasurementService.polygonArea(points)
        case nil:
            return 0
        }
    }

    // MARK: - Actions

    func startMeasuring(mode: MeasurementMode) {
        self.mode = mode
        self.points = []
        self.isActive = true
    }

    func addPoint(_ coordinate: CLLocationCoordinate2D) {
        points.append(coordinate)
    }

    func undoLastPoint() {
        guard !points.isEmpty else { return }
        points.removeLast()
    }

    func movePoint(at index: Int, to coordinate: CLLocationCoordinate2D) {
        guard points.indices.contains(index) else { return }
        points[index] = coordinate
    }

    func clearAll() {
        points.removeAll()
    }

    func stop() {
        isActive = false
        mode = nil
        points.removeAll()
    }
}
