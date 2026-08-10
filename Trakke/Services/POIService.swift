import Foundation
import CoreLocation
import OSLog

// MARK: - POI Service

actor POIService {
    private var cache: [String: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 1800 // 30 minutes
    private static let maxCacheEntries = 50
    private static let poiFetchTimeout: TimeInterval = 25

    struct CacheEntry {
        let pois: [POI]
        let timestamp: Date
    }

    // MARK: - Public API

    func fetchPOIs(
        category: POICategory,
        bounds: ViewportBounds,
        zoom: Double
    ) async -> [POI] {
        guard zoom >= category.minZoom else {
            Logger.poi.debug(
                "\(category.rawValue, privacy: .public): hoppet over, zoom \(zoom, privacy: .public) < \(category.minZoom, privacy: .public)"
            )
            return []
        }
        guard bounds.isValid else {
            Logger.poi.debug("\(category.rawValue, privacy: .public): ugyldig kartutsnitt")
            return []
        }

        let buffered = bounds.buffered()

        // Bundled-only categories are handled synchronously -- no network needed
        if category.isBundled && !category.isLive {
            return await BundledPOIService.pois(for: category, in: buffered)
        }

        // Live categories use network + cache, with bundled fallback
        let key = "\(category.rawValue)-\(buffered.cacheKey)-z\(Int(zoom))"

        if let cached = cache[key], Date().timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            return cached.pois
        }

        // For hybrid categories (bundled + live), get bundled data as baseline
        let bundledFallback: [POI] = category.isBundled
            ? await BundledPOIService.pois(for: category, in: buffered)
            : []

        do {
            try Task.checkCancellation()

            let pois: [POI]
            switch category {
            case .shelters:
                // Live og bundlet er samme datasett med samme id-er, så et
                // treff fra Geonorge erstatter det bundlede rommet.
                pois = try await fetchShelters(bounds: buffered)
            case .kulturminner:
                // To ulike registre: Riksantikvarens brukerminner og UT.no sine
                // kulturminner. Ingen felles id, så de slås sammen framfor at
                // det ene erstatter det andre – ellers ville nett-tilgang
                // *fjerne* de bundlede kulturminnene fra kartet.
                let live = try await fetchKulturminner(bounds: buffered)
                pois = live + Self.notCovered(by: live, in: bundledFallback)
            default:
                return bundledFallback
            }

            // Logg antallet, ikke bare feil. Et kall som lykkes og gir null
            // treff så tidligere nøyaktig ut som at kategorien var i stykker:
            // ingenting på kartet, ingenting i loggen.
            Logger.poi.debug(
                "\(category.rawValue, privacy: .public): \(pois.count, privacy: .public) treff fra API"
            )
            cache[key] = CacheEntry(pois: pois, timestamp: Date())
            cleanCache()
            return pois
        } catch is CancellationError {
            return cache[key]?.pois ?? bundledFallback
        } catch let urlError as URLError where urlError.code == .cancelled {
            return cache[key]?.pois ?? bundledFallback
        } catch {
            Logger.poi.error("POI fetch error (\(category.rawValue, privacy: .public)): \(error, privacy: .private)")
            return cache[key]?.pois ?? bundledFallback
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    /// The bundled POIs that no live POI already covers. Two registers describing
    /// the same site would otherwise draw two markers on top of each other.
    /// 50 m is wide enough for the two registers' differing coordinates for the
    /// same object, and narrow enough to keep two nearby ruins apart.
    private static let duplicateRadius: CLLocationDistance = 50

    private static func notCovered(by live: [POI], in bundled: [POI]) -> [POI] {
        guard !live.isEmpty, !bundled.isEmpty else { return bundled }

        // A degree of latitude is ~111 km everywhere, so 50 m is at most this
        // much latitude. Comparing degrees first keeps the number of
        // `CLLocation.distance` calls down: without it this is 300 × 660
        // trigonometric distance calculations per viewport fetch.
        let latitudeWindow = duplicateRadius / 111_000
        let sortedLive = live.sorted { $0.coordinate.latitude < $1.coordinate.latitude }
        let liveLatitudes = sortedLive.map(\.coordinate.latitude)

        return bundled.filter { candidate in
            let latitude = candidate.coordinate.latitude
            // Binary search for the first live POI within the latitude window.
            var low = 0
            var high = liveLatitudes.count
            while low < high {
                let mid = (low + high) / 2
                if liveLatitudes[mid] < latitude - latitudeWindow { low = mid + 1 } else { high = mid }
            }

            let location = CLLocation(latitude: latitude, longitude: candidate.coordinate.longitude)
            var index = low
            while index < sortedLive.count, sortedLive[index].coordinate.latitude <= latitude + latitudeWindow {
                let other = sortedLive[index].coordinate
                let otherLocation = CLLocation(latitude: other.latitude, longitude: other.longitude)
                if otherLocation.distance(from: location) <= duplicateRadius { return false }
                index += 1
            }
            return true
        }
    }

    // MARK: - Tilfluktsrom (Geonorge WFS/GML)

    /// Public shelters come from Geonorge's WFS 2.0.0 service, the distribution
    /// Geonorge lists for DSB's dataset. It gives a stable UUID per shelter
    /// (`app:lokalId`), which DSB's own mapserver at `ogc.dsb.no` does not.
    /// The bundled copy is produced from the same service by
    /// `Scripts/fetch_dsb_shelters.swift` and remains the offline baseline.
    ///
    /// `BBOX` is `minLat,minLon,maxLat,maxLon` — EPSG:4326 is latitude-first in
    /// WFS 2.0.0, and passing lon-first returns zero features without an error.
    private func fetchShelters(bounds: ViewportBounds) async throws -> [POI] {
        guard var components = URLComponents(string: "https://wfs.geonorge.no/skwms1/wfs.tilfluktsrom_offentlige") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typenames", value: "app:Tilfluktsrom"),
            URLQueryItem(name: "srsName", value: "urn:ogc:def:crs:EPSG::4326"),
            URLQueryItem(name: "bbox", value: "\(bounds.south),\(bounds.west),\(bounds.north),\(bounds.east),urn:ogc:def:crs:EPSG::4326"),
        ]

        guard let url = components.url else { return [] }
        let data = try await APIClient.fetchData(url: url, timeout: Self.poiFetchTimeout)
        return parseShelterGML(data)
    }

    private func parseShelterGML(_ data: Data) -> [POI] {
        let parser = ShelterGMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldResolveExternalEntities = false
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.pois
    }

    // MARK: - Riksantikvaren (GeoJSON)

    /// The Riksantikvaren API truncates responses at ~328 KB, producing invalid JSON
    /// when too many features are returned. We fetch in pages of 100 (the safe maximum)
    /// up to a maximum of 3 pages to balance coverage with network efficiency.
    private static let kulturminnerPageSize = 100
    private static let kulturminnerMaxPages = 3

    private func fetchKulturminner(bounds: ViewportBounds) async throws -> [POI] {
        var allPOIs: [POI] = []
        var offset = 0
        var hasMore = true
        let decoder = JSONDecoder()

        for page in 0..<Self.kulturminnerMaxPages {
            guard hasMore else { break }
            if page > 0 {
                try Task.checkCancellation()
            }

            guard var components = URLComponents(string: "https://api.ra.no/brukerminner/collections/brukerminner/items") else {
                return allPOIs
            }
            components.queryItems = [
                URLQueryItem(name: "f", value: "json"),
                URLQueryItem(name: "bbox", value: "\(bounds.west),\(bounds.south),\(bounds.east),\(bounds.north)"),
                URLQueryItem(name: "limit", value: "\(Self.kulturminnerPageSize)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
            ]

            guard let url = components.url else { return allPOIs }
            let data = try await APIClient.fetchData(
                url: url,
                timeout: Self.poiFetchTimeout,
                additionalHeaders: ["Accept": "application/geo+json"]
            )
            let response = try decoder.decode(KulturminnerResponse.self, from: data)
            let rawCount = response.features.count
            let pois = response.features.compactMap { feature -> POI? in
                guard feature.geometry.type == "Point",
                      feature.geometry.coordinates.count >= 2 else { return nil }

                let lon = feature.geometry.coordinates[0]
                let lat = feature.geometry.coordinates[1]
                guard lat.isFinite, lon.isFinite else { return nil }

                let name = feature.properties.tittel ?? String(localized: "poi.kulturminner")

                var details: [String: String] = [:]
                if let desc = feature.properties.beskrivelse { details["description"] = desc }
                if let kommune = feature.properties.kommune { details["municipality"] = kommune }
                if let fylke = feature.properties.fylke { details["county"] = fylke }
                if let link = feature.properties.linkkulturminnesok { details["link"] = link }

                return POI(
                    id: feature.id ?? "kulturminner-\(lat)-\(lon)",
                    category: .kulturminner,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    details: details
                )
            }

            allPOIs.append(contentsOf: pois)
            offset += Self.kulturminnerPageSize

            // Use raw feature count (before geometry filtering) to detect the last page.
            hasMore = rawCount >= Self.kulturminnerPageSize
        }

        return allPOIs
    }

    // MARK: - Cache Management

    private func cleanCache() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < Self.cacheTTL }

        if cache.count > Self.maxCacheEntries {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(cache.count - Self.maxCacheEntries)
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - Fault-Tolerant Decoding

private struct SafeDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

// MARK: - Riksantikvaren Response Types

private struct KulturminnerResponse: Decodable {
    let features: [KulturminnerFeature]

    private enum CodingKeys: String, CodingKey {
        case features
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let safe = try container.decode([SafeDecodable<KulturminnerFeature>].self, forKey: .features)
        features = safe.compactMap(\.value)
    }
}

private struct KulturminnerFeature: Decodable {
    let id: String?
    let geometry: KulturminnerGeometry
    let properties: KulturminnerProperties

    private enum CodingKeys: String, CodingKey {
        case id, geometry, properties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = nil
        }
        geometry = try container.decode(KulturminnerGeometry.self, forKey: .geometry)
        properties = try container.decode(KulturminnerProperties.self, forKey: .properties)
    }
}

private struct KulturminnerGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}

private struct KulturminnerProperties: Decodable {
    let tittel: String?
    let beskrivelse: String?
    let kommune: String?
    let fylke: String?
    let linkkulturminnesok: String?
}

// MARK: - Tilfluktsrom GML Parser

/// Parses the Geonorge WFS 2.0.0 response (GML 3.2). Features arrive in
/// `wfs:member`; `app:lokalId` is the stable identity. The DSB attribute
/// `t_kategori` (construction standard, "76-Rom A" and similar) was removed
/// upstream in 2026 and is not read.
private class ShelterGMLParser: NSObject, XMLParserDelegate {
    var pois: [POI] = []

    private var currentText = ""
    private var inFeature = false
    private var localId: String?
    private var romnr: String?
    private var adresse: String?
    private var plasser: String?
    private var coordinates: String?

    private static let featureElements: Set<String> = ["featureMember", "member"]

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        currentText = ""

        if Self.featureElements.contains(name) {
            inFeature = true
            localId = nil
            romnr = nil
            adresse = nil
            plasser = nil
            coordinates = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inFeature {
            switch name {
            case "lokalId": localId = text
            case "romnr": romnr = text
            case "adresse": adresse = text
            case "plasser": plasser = text
            case "pos": coordinates = text
            default: break
            }
        }

        if Self.featureElements.contains(name) {
            inFeature = false
            if let coordStr = coordinates {
                // GML pos format: "lat lon"
                let parts = coordStr.split(separator: " ")
                if parts.count >= 2,
                   let lat = Double(parts[0]),
                   let lon = Double(parts[1]),
                   lat.isFinite, lon.isFinite {

                    // Same id scheme as the bundled file, so a live result
                    // replaces the bundled record for the same shelter.
                    let id: String
                    if let localId, !localId.isEmpty {
                        id = localId
                    } else if let romnr, !romnr.isEmpty {
                        id = "romnr-\(romnr)"
                    } else {
                        id = "\(lat)-\(lon)"
                    }
                    let displayName = "Tilfluktsrom \(romnr ?? "")"

                    var details: [String: String] = [:]
                    if let addr = adresse { details["address"] = addr }
                    if let cap = plasser { details["capacity"] = cap }

                    pois.append(POI(
                        id: "shelter-\(id)",
                        category: .shelters,
                        name: displayName.trimmingCharacters(in: .whitespaces),
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        details: details
                    ))
                }
            }
        }
    }
}
