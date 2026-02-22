import Foundation
import CoreLocation

/// A route computed by the Valhalla routing engine.
struct ComputedRoute: Sendable {
    let coordinates: [CLLocationCoordinate2D]
    let distance: Double            // meters
    let duration: TimeInterval      // seconds
    let ascent: Double              // meters
    let descent: Double             // meters
    let instructions: [TurnInstruction]
    let summary: String             // e.g. "Leirdalvegen, Sognefjellsvegen"
}
