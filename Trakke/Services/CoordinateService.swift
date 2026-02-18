import Foundation
import CoreLocation
import MGRS

// MARK: - Coordinate Format

enum CoordinateFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case dd
    case dms
    case ddm
    case utm
    case mgrs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dd: return "DD"
        case .dms: return "DMS"
        case .ddm: return "DDM"
        case .utm: return "UTM"
        case .mgrs: return "MGRS"
        }
    }
}

// MARK: - Formatted Coordinate

struct FormattedCoordinate: Sendable {
    let display: String
    let copyText: String
}

// MARK: - Coordinate Service

enum CoordinateService {

    // MARK: - Norway Bounds

    private static let norwayLatRange = 55.0...75.0
    private static let norwayLonRange = 2.0...35.0

    // MARK: - Formatting

    static func format(
        coordinate: CLLocationCoordinate2D,
        format: CoordinateFormat
    ) -> FormattedCoordinate {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        switch format {
        case .dd:
            return formatDD(lat: lat, lon: lon)
        case .dms:
            return formatDMS(lat: lat, lon: lon)
        case .ddm:
            return formatDDM(lat: lat, lon: lon)
        case .utm:
            return formatUTM(lat: lat, lon: lon)
        case .mgrs:
            return formatMGRS(lat: lat, lon: lon)
        }
    }

    private static func formatDD(lat: Double, lon: Double) -> FormattedCoordinate {
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        let display = String(format: "%.6f\u{00B0}%@, %.6f\u{00B0}%@", abs(lat), latDir, abs(lon), lonDir)
        let copy = String(format: "%.6f, %.6f", lat, lon)
        return FormattedCoordinate(display: display, copyText: copy)
    }

    private static func formatDMS(lat: Double, lon: Double) -> FormattedCoordinate {
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"

        let (latD, latM, latS) = decimalToDMS(abs(lat))
        let (lonD, lonM, lonS) = decimalToDMS(abs(lon))

        let display = String(
            format: "%d\u{00B0}%d\u{2032}%.1f\u{2033}%@, %d\u{00B0}%d\u{2032}%.1f\u{2033}%@",
            latD, latM, latS, latDir, lonD, lonM, lonS, lonDir
        )
        return FormattedCoordinate(display: display, copyText: display)
    }

    private static func formatDDM(lat: Double, lon: Double) -> FormattedCoordinate {
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"

        let (latD, latDM) = decimalToDDM(abs(lat))
        let (lonD, lonDM) = decimalToDDM(abs(lon))

        let display = String(
            format: "%d\u{00B0}%.3f\u{2032}%@, %d\u{00B0}%.3f\u{2032}%@",
            latD, latDM, latDir, lonD, lonDM, lonDir
        )
        return FormattedCoordinate(display: display, copyText: display)
    }

    private static func formatUTM(lat: Double, lon: Double) -> FormattedCoordinate {
        let zone = utmZone(longitude: lon)
        let band = utmBand(latitude: lat)
        let (easting, northing) = latLonToUTM(lat: lat, lon: lon, zone: zone)

        let display = String(format: "%d%@ %.0fE %.0fN", zone, band, easting, northing)
        let copy = String(format: "%d%@ %.0f %.0f", zone, band, easting, northing)
        return FormattedCoordinate(display: display, copyText: copy)
    }

    private static func formatMGRS(lat: Double, lon: Double) -> FormattedCoordinate {
        let mgrsObj = MGRS.from(lon, lat)
        let mgrsString = mgrsObj.coordinate(GridType.METER)

        // Format with spaces: "32V NM 97423 71394"
        if mgrsString.count >= 5 {
            let idx = mgrsString.startIndex
            let zoneEnd = mgrsString.index(idx, offsetBy: mgrsString.count >= 3 && mgrsString[mgrsString.index(idx, offsetBy: 2)].isLetter ? 3 : 2)
            let zone = String(mgrsString[idx..<zoneEnd])
            let rest = String(mgrsString[zoneEnd...])

            if rest.count >= 2 {
                let square = String(rest.prefix(2))
                let coords = String(rest.dropFirst(2))
                let half = coords.count / 2
                let easting = String(coords.prefix(half))
                let northing = String(coords.suffix(half))

                let display = "\(zone) \(square) \(easting) \(northing)"
                return FormattedCoordinate(display: display, copyText: mgrsString)
            }
        }

        return FormattedCoordinate(display: mgrsString, copyText: mgrsString)
    }

    // MARK: - Parsing

    static func parse(_ input: String) -> SearchResult? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let result = parseMGRS(trimmed) { return result }
        if let result = parseUTM(trimmed) { return result }
        if let result = parseDMS(trimmed) { return result }
        if let result = parseDDM(trimmed) { return result }
        if let result = parseDD(trimmed) { return result }

        return nil
    }

    // MARK: DD Parsing

    private static func parseDD(_ input: String) -> SearchResult? {
        // Pattern with direction letters: N59.9139 E10.7522
        let dirPattern = #"^([NS])?(-?\d+\.?\d*)[°]?([NS])?\s*[,\s]\s*([EWØ])?(-?\d+\.?\d*)[°]?([EWØ])?$"#
        if let regex = try? NSRegularExpression(pattern: dirPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

            let val1 = extractDouble(from: input, match: match, group: 2)
            let val2 = extractDouble(from: input, match: match, group: 5)
            let dir1Pre = extractString(from: input, match: match, group: 1)?.uppercased()
            let dir1Post = extractString(from: input, match: match, group: 3)?.uppercased()
            let dir2Pre = extractString(from: input, match: match, group: 4)?.uppercased()
            let dir2Post = extractString(from: input, match: match, group: 6)?.uppercased()

            guard let v1 = val1, let v2 = val2 else { return nil }

            let dir1 = dir1Pre ?? dir1Post
            let dir2 = dir2Pre ?? dir2Post

            var lat = v1
            var lon = v2

            if dir1 == "S" { lat = -abs(lat) }
            if dir2 == "W" { lon = -abs(lon) }
            // Ø is Norwegian for East (no sign change)

            if let coordinate = resolveLatLon(lat: lat, lon: lon) {
                return makeCoordinateResult(coordinate: coordinate, label: "DD")
            }
        }

        // Simple pattern: 59.9139, 10.7522
        let simplePattern = #"^(-?\d+\.?\d*)\s*[,\s]\s*(-?\d+\.?\d*)$"#
        if let regex = try? NSRegularExpression(pattern: simplePattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            let v1 = extractDouble(from: input, match: match, group: 1)
            let v2 = extractDouble(from: input, match: match, group: 2)
            guard let lat = v1, let lon = v2 else { return nil }

            if let coordinate = resolveLatLon(lat: lat, lon: lon) {
                return makeCoordinateResult(coordinate: coordinate, label: "DD")
            }
        }

        return nil
    }

    // MARK: DMS Parsing

    private static func parseDMS(_ input: String) -> SearchResult? {
        let pattern = "(\\d+)[\u{00B0}]\\s*(\\d+)['\u{2032}]\\s*(\\d+\\.?\\d*)[\"\u{2033}]?\\s*([NS])\\s*[,\\s]\\s*(\\d+)[\u{00B0}]\\s*(\\d+)['\u{2032}]\\s*(\\d+\\.?\\d*)[\"\u{2033}]?\\s*([EW\u{00D8}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        guard let latD = extractDouble(from: input, match: match, group: 1),
              let latM = extractDouble(from: input, match: match, group: 2),
              let latS = extractDouble(from: input, match: match, group: 3),
              let latDir = extractString(from: input, match: match, group: 4)?.uppercased(),
              let lonD = extractDouble(from: input, match: match, group: 5),
              let lonM = extractDouble(from: input, match: match, group: 6),
              let lonS = extractDouble(from: input, match: match, group: 7),
              let lonDir = extractString(from: input, match: match, group: 8)?.uppercased() else {
            return nil
        }

        var lat = latD + latM / 60.0 + latS / 3600.0
        var lon = lonD + lonM / 60.0 + lonS / 3600.0

        if latDir == "S" { lat = -lat }
        if lonDir == "W" { lon = -lon }

        guard isValidCoordinate(lat: lat, lon: lon) else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return makeCoordinateResult(coordinate: coordinate, label: "DMS")
    }

    // MARK: DDM Parsing

    private static func parseDDM(_ input: String) -> SearchResult? {
        let pattern = "(\\d+)[\u{00B0}]\\s*(\\d+\\.?\\d*)['\u{2032}]\\s*([NS])\\s*[,\\s]\\s*(\\d+)[\u{00B0}]\\s*(\\d+\\.?\\d*)['\u{2032}]\\s*([EW\u{00D8}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        guard let latD = extractDouble(from: input, match: match, group: 1),
              let latDM = extractDouble(from: input, match: match, group: 2),
              let latDir = extractString(from: input, match: match, group: 3)?.uppercased(),
              let lonD = extractDouble(from: input, match: match, group: 4),
              let lonDM = extractDouble(from: input, match: match, group: 5),
              let lonDir = extractString(from: input, match: match, group: 6)?.uppercased() else {
            return nil
        }

        var lat = latD + latDM / 60.0
        var lon = lonD + lonDM / 60.0

        if latDir == "S" { lat = -lat }
        if lonDir == "W" { lon = -lon }

        guard isValidCoordinate(lat: lat, lon: lon) else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return makeCoordinateResult(coordinate: coordinate, label: "DDM")
    }

    // MARK: UTM Parsing

    private static func parseUTM(_ input: String) -> SearchResult? {
        let pattern = #"^(\d{1,2})\s*([C-HJ-NP-X])\s+(\d{5,7})\s*[EØ]?\s+(\d{6,8})\s*N?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        guard let zone = extractInt(from: input, match: match, group: 1),
              let band = extractString(from: input, match: match, group: 2)?.uppercased(),
              let easting = extractDouble(from: input, match: match, group: 3),
              let northing = extractDouble(from: input, match: match, group: 4) else {
            return nil
        }

        guard (1...60).contains(zone) else { return nil }

        let isNorth = "NPQRSTUVWX".contains(band)
        let (lat, lon) = utmToLatLon(easting: easting, northing: northing, zone: zone, isNorth: isNorth)

        guard isValidCoordinate(lat: lat, lon: lon) else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return makeCoordinateResult(coordinate: coordinate, label: "UTM")
    }

    // MARK: MGRS Parsing

    private static func parseMGRS(_ input: String) -> SearchResult? {
        // Remove spaces for pattern matching
        let cleaned = input.replacingOccurrences(of: " ", with: "")
        let pattern = #"^(\d{1,2})([C-HJ-NP-X])([A-HJ-NP-Z]{2})(\d{2,10})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil else {
            return nil
        }

        guard MGRS.isMGRS(cleaned) else { return nil }
        let mgrsObj = MGRS.parse(cleaned)
        let coord = mgrsObj.toCoordinate()
        let lat = coord.latitude
        let lon = coord.longitude

        guard isValidCoordinate(lat: lat, lon: lon) else { return nil }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return makeCoordinateResult(coordinate: coordinate, label: "MGRS")
    }

    // MARK: - Helpers

    private static func extractString(from string: String, match: NSTextCheckingResult, group: Int) -> String? {
        guard group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: string),
              !string[range].isEmpty else { return nil }
        return String(string[range])
    }

    private static func extractDouble(from string: String, match: NSTextCheckingResult, group: Int) -> Double? {
        guard let str = extractString(from: string, match: match, group: group) else { return nil }
        return Double(str)
    }

    private static func extractInt(from string: String, match: NSTextCheckingResult, group: Int) -> Int? {
        guard let str = extractString(from: string, match: match, group: group) else { return nil }
        return Int(str)
    }

    private static func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        (-90...90).contains(lat) && (-180...180).contains(lon)
    }

    private static func isInNorway(lat: Double, lon: Double) -> Bool {
        norwayLatRange.contains(lat) && norwayLonRange.contains(lon)
    }

    private static func resolveLatLon(lat: Double, lon: Double) -> CLLocationCoordinate2D? {
        guard isValidCoordinate(lat: lat, lon: lon) else {
            // Try swapped
            if isValidCoordinate(lat: lon, lon: lat) {
                return CLLocationCoordinate2D(latitude: lon, longitude: lat)
            }
            return nil
        }

        // If in Norway bounds, use as-is
        if isInNorway(lat: lat, lon: lon) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        // If swapped fits Norway better
        if isInNorway(lat: lon, lon: lat) {
            return CLLocationCoordinate2D(latitude: lon, longitude: lat)
        }

        // Default: first = lat, second = lon
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func makeCoordinateResult(coordinate: CLLocationCoordinate2D, label: String) -> SearchResult {
        let dd = formatDD(lat: coordinate.latitude, lon: coordinate.longitude)
        return SearchResult(
            id: "coord-\(coordinate.latitude)-\(coordinate.longitude)",
            name: dd.display,
            type: .coordinates,
            coordinate: coordinate,
            displayName: dd.display,
            subtext: label
        )
    }

    // MARK: - DMS/DDM Conversion Helpers

    private static func decimalToDMS(_ decimal: Double) -> (Int, Int, Double) {
        let degrees = Int(decimal)
        let minutesDecimal = (decimal - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60
        return (degrees, minutes, seconds)
    }

    private static func decimalToDDM(_ decimal: Double) -> (Int, Double) {
        let degrees = Int(decimal)
        let minutes = (decimal - Double(degrees)) * 60
        return (degrees, minutes)
    }

    // MARK: - UTM Conversion

    private static let utmBands = "CDEFGHJKLMNPQRSTUVWX"

    static func utmZone(longitude: Double) -> Int {
        Int(floor((longitude + 180) / 6)) + 1
    }

    static func utmBand(latitude: Double) -> String {
        let index = Int(floor((latitude + 80) / 8))
        let clamped = max(0, min(index, utmBands.count - 1))
        return String(utmBands[utmBands.index(utmBands.startIndex, offsetBy: clamped)])
    }

    private static func latLonToUTM(lat: Double, lon: Double, zone: Int) -> (easting: Double, northing: Double) {
        let a = 6378137.0 // WGS84 semi-major axis
        let f = 1 / 298.257223563
        let k0 = 0.9996

        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180

        let lonOrigin = Double((zone - 1) * 6 - 180 + 3)
        let lonOriginRad = lonOrigin * .pi / 180

        let e2 = 2 * f - f * f
        let ep2 = e2 / (1 - e2)

        let n = a / sqrt(1 - e2 * sin(latRad) * sin(latRad))
        let t = tan(latRad) * tan(latRad)
        let c = ep2 * cos(latRad) * cos(latRad)
        let aCoef = cos(latRad) * (lonRad - lonOriginRad)

        let m = a * (
            (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * latRad
            - (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) * sin(2 * latRad)
            + (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) * sin(4 * latRad)
            - (35 * e2 * e2 * e2 / 3072) * sin(6 * latRad)
        )

        let easting = k0 * n * (
            aCoef
            + (1 - t + c) * aCoef * aCoef * aCoef / 6
            + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * aCoef * aCoef * aCoef * aCoef * aCoef / 120
        ) + 500000.0

        var northing = k0 * (
            m + n * tan(latRad) * (
                aCoef * aCoef / 2
                + (5 - t + 9 * c + 4 * c * c) * aCoef * aCoef * aCoef * aCoef / 24
                + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * aCoef * aCoef * aCoef * aCoef * aCoef * aCoef / 720
            )
        )

        if lat < 0 {
            northing += 10000000.0
        }

        return (easting, northing)
    }

    private static func utmToLatLon(easting: Double, northing: Double, zone: Int, isNorth: Bool) -> (lat: Double, lon: Double) {
        let a = 6378137.0
        let f = 1 / 298.257223563
        let k0 = 0.9996

        let e2 = 2 * f - f * f
        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))
        let ep2 = e2 / (1 - e2)

        let x = easting - 500000.0
        var y = northing
        if !isNorth { y -= 10000000.0 }

        let lonOrigin = Double((zone - 1) * 6 - 180 + 3)

        let m = y / k0
        let mu = m / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256))

        let phi1Rad = mu
            + (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32) * sin(2 * mu)
            + (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32) * sin(4 * mu)
            + (151 * e1 * e1 * e1 / 96) * sin(6 * mu)
            + (1097 * e1 * e1 * e1 * e1 / 512) * sin(8 * mu)

        let n1 = a / sqrt(1 - e2 * sin(phi1Rad) * sin(phi1Rad))
        let t1 = tan(phi1Rad) * tan(phi1Rad)
        let c1 = ep2 * cos(phi1Rad) * cos(phi1Rad)
        let r1 = a * (1 - e2) / pow(1 - e2 * sin(phi1Rad) * sin(phi1Rad), 1.5)
        let d = x / (n1 * k0)

        let lat = phi1Rad - (n1 * tan(phi1Rad) / r1) * (
            d * d / 2
            - (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) * d * d * d * d / 24
            + (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * ep2 - 3 * c1 * c1) * d * d * d * d * d * d / 720
        )

        let lon = (
            d
            - (1 + 2 * t1 + c1) * d * d * d / 6
            + (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1) * d * d * d * d * d / 120
        ) / cos(phi1Rad)

        return (lat * 180 / .pi, lonOrigin + lon * 180 / .pi)
    }
}
