import Foundation
import CoreLocation

/// Decodes Valhalla's polyline6 encoded strings (precision 1e-6) into coordinates.
/// Valhalla uses precision 6 (1e-6), unlike Google's standard polyline which uses precision 5 (1e-5).
enum Polyline6Decoder {

    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat = 0
        var lon = 0

        while index < encoded.endIndex {
            lat += decodeNextValue(from: encoded, index: &index)
            guard index <= encoded.endIndex else { break }
            lon += decodeNextValue(from: encoded, index: &index)

            let latitude = Double(lat) / 1e6
            let longitude = Double(lon) / 1e6

            guard latitude.isFinite, longitude.isFinite,
                  latitude >= -90, latitude <= 90,
                  longitude >= -180, longitude <= 180 else {
                continue
            }

            coordinates.append(CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            ))
        }

        return coordinates
    }

    private static func decodeNextValue(
        from encoded: String,
        index: inout String.Index
    ) -> Int {
        var result = 0
        var shift = 0

        while index < encoded.endIndex {
            let char = encoded[index]
            encoded.formIndex(after: &index)

            let value = Int(char.asciiValue ?? 0) - 63
            result |= (value & 0x1F) << shift
            shift += 5

            if value < 0x20 { break }
        }

        // Invert if negative
        if result & 1 != 0 {
            return ~(result >> 1)
        }
        return result >> 1
    }
}
