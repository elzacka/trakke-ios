import Foundation
import CoreLocation

enum Bearing {
    /// Initial bearing from one coordinate to another (degrees 0-360).
    static func bearing(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        let lat1 = c1.latitude * .pi / 180
        let lat2 = c2.latitude * .pi / 180
        let dLon = (c2.longitude - c1.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let theta = atan2(y, x)

        return (theta * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
