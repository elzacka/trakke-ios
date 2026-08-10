import CoreLocation
import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: String
    var name: String
    /// GPS track as [[longitude, latitude, altitude, timestamp, horizontalAccuracy,
    /// speed, course]] arrays. The four first values have been there since the
    /// first release; anything after them is additive and may be missing on
    /// activities recorded by older builds. Read through the accessors below,
    /// never by index — they all guard on `count`.
    var trackPoints: [[Double]]
    var distance: Double
    var elevationGain: Double
    var elevationLoss: Double
    var duration: TimeInterval
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date
    var isVisible: Bool = false
    /// Optional user-defined category for grouping in the activity list (mirrors
    /// the Waypoint.category pattern). nil → "Ukategorisert" group.
    var category: String?

    init(
        name: String,
        trackPoints: [[Double]] = [],
        distance: Double = 0,
        elevationGain: Double = 0,
        elevationLoss: Double = 0,
        duration: TimeInterval = 0,
        startedAt: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.trackPoints = trackPoints
        self.distance = distance
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.duration = duration
        self.startedAt = startedAt
        self.createdAt = Date()
        self.isVisible = false
        self.category = nil
    }

    /// Coordinates as CLLocationCoordinate2D-compatible [[lon, lat]] (same format as Route)
    var coordinates: [[Double]] {
        trackPoints.map { point in
            guard point.count >= 2 else { return [0, 0] }
            return [point[0], point[1]]
        }
    }

    /// Altitudes extracted from track points
    var altitudes: [Double] {
        trackPoints.compactMap { point in
            guard point.count >= 3 else { return nil }
            return point[2]
        }
    }

    // MARK: - Track point accessors

    /// Horisontal nøyaktighet i meter, `nil` for turer tatt opp før feltet
    /// fantes. Den er verdt å beholde nettopp fordi den lar en si at *denne*
    /// delen av sporet er upålitelig, i stedet for å tegne alt som like sikkert.
    static func horizontalAccuracy(of point: [Double]) -> Double? {
        guard point.count >= 5, point[4] >= 0 else { return nil }
        return point[4]
    }

    /// Fart i meter per sekund. CoreLocation bruker negative verdier for
    /// «vet ikke», og de skal ikke havne i statistikken.
    static func speed(of point: [Double]) -> Double? {
        guard point.count >= 6, point[5] >= 0 else { return nil }
        return point[5]
    }

    /// Kurs i grader fra nord.
    static func course(of point: [Double]) -> Double? {
        guard point.count >= 7, point[6] >= 0 else { return nil }
        return point[6]
    }

    static func timestamp(of point: [Double]) -> Date? {
        guard point.count >= 4 else { return nil }
        return Date(timeIntervalSince1970: point[3])
    }

    /// Høyde i meter, eller `nil` når punktet ikke har en målt høyde.
    ///
    /// Opptaket skriver 0 når høyden ikke er målt, og 0 meter over havet er
    /// samtidig en gyldig måling. `verticalAccuracy` løser tvetydigheten for
    /// nyere turer. For turer tatt opp før feltet fantes finnes ikke svaret,
    /// og da er den gamle regelen – 0 betyr ukjent – det eneste vi har.
    static func altitude(of point: [Double]) -> Double? {
        guard point.count >= 3, point[2].isFinite else { return nil }
        if point.count >= 8 {
            return point[7] >= 0 ? point[2] : nil
        }
        return point[2] > 0 ? point[2] : nil
    }

    // MARK: - Derived statistics

    /// Statistikken er avledet, ikke lagret. Den regnes fra sporet hver gang,
    /// så gamle turer får de samme tallene som nye — så langt punktene deres
    /// rekker — og en rettet utregning trenger ingen migrering.
    var maxSpeed: Double {
        trackPoints.compactMap(Self.speed).max() ?? 0
    }

    /// Målte høyder, uten de ikke-målte. Går gjennom `altitude(of:)` slik at
    /// et ekte havnivå ikke forveksles med manglende data.
    var measuredAltitudes: [Double] {
        trackPoints.compactMap(Self.altitude)
    }

    var minAltitude: Double? { measuredAltitudes.min() }

    var maxAltitude: Double? { measuredAltitudes.max() }

    /// Tid der du faktisk var i bevegelse. Et opphold vises nå i sporet som et
    /// tidshopp uten forflytning, og det er dét som skiller bevegelsestid fra
    /// totaltid. Terskelen er den samme støygrensa som opptaket bruker.
    var movingDuration: TimeInterval {
        var moving: TimeInterval = 0
        for (previous, current) in zip(trackPoints, trackPoints.dropFirst()) {
            guard let from = Self.timestamp(of: previous),
                  let to = Self.timestamp(of: current),
                  previous.count >= 2, current.count >= 2 else { continue }
            let step = Haversine.distance(
                from: CLLocationCoordinate2D(latitude: previous[1], longitude: previous[0]),
                to: CLLocationCoordinate2D(latitude: current[1], longitude: current[0])
            )
            guard step >= Self.movingStepThreshold else { continue }
            let elapsed = to.timeIntervalSince(from)
            // Et hull i sporet – appen ble avlivet, GPS-en mistet signal under
            // et fjell – er ikke bevegelsestid, selv om punktene på hver side
            // ligger langt fra hverandre. Uten dette taket ville en time uten
            // dekning blitt lagt til som en time i bevegelse.
            guard elapsed > 0, elapsed <= Self.maxMovingStepInterval else { continue }
            moving += elapsed
        }
        return moving
    }

    /// Hvilepausen: totaltid minus bevegelsestid.
    var pausedDuration: TimeInterval {
        max(0, duration - movingDuration)
    }

    /// Snittfart over tilbakelagt distanse og bevegelsestid, i meter per
    /// sekund. Regnes mot bevegelsestid – ikke totaltid – ellers ville en lang
    /// matpause sett ut som dårlig form.
    var averageMovingSpeed: Double {
        guard movingDuration > 0 else { return 0 }
        return distance / movingDuration
    }

    /// Samme støygrense som opptaket bruker for å skille bevegelse fra
    /// GPS-drift i hvile.
    private static let movingStepThreshold: Double = 2

    /// Lengste steg mellom to punkter som fortsatt regnes som sammenhengende
    /// bevegelse. Opptaket lagrer et punkt minst hvert femte sekund, så alt
    /// over et minutt er et hull i sporet, ikke gange.
    private static let maxMovingStepInterval: TimeInterval = 60
}
