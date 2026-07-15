import Foundation
import CoreLocation

// MARK: - Camera Mode

enum NavigationCameraMode: String, Sendable {
    case northUp
    case courseUp
}

// MARK: - GPS Quality

enum GPSQuality: Sendable {
    case good       // horizontalAccuracy < 20m
    case reduced    // horizontalAccuracy < 50m
    case lost       // horizontalAccuracy >= 50m or no signal

    init(accuracy: CLLocationAccuracy) {
        switch accuracy {
        case ..<0:
            self = .lost
        case ..<20:
            self = .good
        case ..<50:
            self = .reduced
        default:
            self = .lost
        }
    }
}
