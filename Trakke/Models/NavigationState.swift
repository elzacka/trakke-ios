import Foundation
import CoreLocation

// MARK: - Navigation Mode

enum NavigationMode: Sendable {
    case route      // Following a computed or saved route
    case compass    // Bearing/distance to destination
}

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

// MARK: - Snap Result

struct SnapResult: Sendable {
    let segmentIndex: Int
    let snappedCoordinate: CLLocationCoordinate2D
    let crossTrackDistance: Double   // meters off-track
    let alongTrackDistance: Double   // meters from route start to snapped point
    let routeBearing: Double        // bearing of route at snap point (degrees 0-360)
}

// MARK: - Navigation Progress

struct NavigationProgress: Sendable {
    let distanceRemaining: Double
    let distanceTraveled: Double
    let totalDistance: Double
    let elevationGainRemaining: Double
    let elevationLossRemaining: Double
    let estimatedTimeRemaining: TimeInterval
    let currentSegmentIndex: Int
    let fractionCompleted: Double
}

// MARK: - Turn Instruction

struct TurnInstruction: Sendable, Identifiable {
    let id = UUID()
    let text: String            // Norwegian instruction text from Valhalla
    let distance: Double        // distance from route start to this instruction
    let coordinate: CLLocationCoordinate2D
    let type: TurnType
}

enum TurnType: String, Sendable {
    case straight
    case slightRight
    case right
    case sharpRight
    case slightLeft
    case left
    case sharpLeft
    case uTurn
    case destination
    case depart
    case ferry
    case other
}
