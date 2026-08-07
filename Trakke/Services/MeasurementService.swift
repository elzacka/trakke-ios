import Foundation
import CoreLocation

enum MeasurementService {
    // MARK: - Distance

    static func distance(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        Haversine.distance(from: c1, to: c2)
    }

    static func polylineDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        Haversine.totalDistance(coordinates: coordinates)
    }

    // MARK: - Area (Spherical Polygon)

    static func polygonArea(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0 }

        let earthRadius = 6371000.0
        var coords = coordinates

        // Close polygon if needed
        if let first = coords.first, let last = coords.last,
           first.latitude != last.latitude || first.longitude != last.longitude {
            coords.append(first)
        }

        var area = 0.0
        for i in 0..<(coords.count - 1) {
            let lon1 = coords[i].longitude * .pi / 180
            let lon2 = coords[i + 1].longitude * .pi / 180
            let lat1 = coords[i].latitude * .pi / 180
            let lat2 = coords[i + 1].latitude * .pi / 180

            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        return abs(area * earthRadius * earthRadius / 2)
    }

    // MARK: - Formatting

    /// Tall til visning, med brukerens desimaltegn. `String(format:)` uten
    /// `locale:` er språkuavhengig og gir alltid punktum, så hele appen viste
    /// «1.2 km» der norsk skal ha «1,2 km». Målt: uten locale «2.4», med
    /// `Locale.current` på nb_NO «2,4».
    ///
    /// Gjelder ikke koordinater og API-parametre. Der er punktum riktig:
    /// koordinater kopieres ut til andre tjenester, og en komma-desimal i en
    /// URL-parameter ville brutt kallet.
    nonisolated static func decimal(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", locale: Locale.current, value)
    }

    /// Fast mellomrom mellom tall og enhet. Norsk tegnsetting skiller dem med
    /// mellomrom, og et vanlig mellomrom lar «1,2» og «km» havne på hver sin
    /// linje i en trang celle.
    nonisolated static func withUnit(_ number: String, _ unit: String) -> String {
        number + "\u{00A0}" + unit
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return withUnit(decimal(meters / 1000, digits: 1), "km")
        }
        return withUnit(decimal(meters, digits: 0), "m")
    }


    static func formatElevation(_ meters: Double) -> String {
        withUnit("\(Int(meters.rounded()))", "m")
    }

    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 10_000 {
            return withUnit(decimal(squareMeters / 1_000_000, digits: 2), "km\u{00B2}")
        }
        return withUnit(decimal(squareMeters, digits: 0), "m\u{00B2}")
    }
}
