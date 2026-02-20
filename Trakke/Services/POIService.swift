import Foundation
import CoreLocation

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
        guard zoom >= category.minZoom else { return [] }
        guard bounds.isValid else { return [] }

        let buffered = bounds.buffered()

        // Bundled categories are handled synchronously -- no network needed
        if category.isBundled {
            return await BundledPOIService.pois(for: category, in: buffered)
        }

        // Live categories use network + cache
        let key = "\(category.rawValue)-\(buffered.cacheKey)-z\(Int(zoom))"

        if let cached = cache[key], Date().timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            return cached.pois
        }

        do {
            try Task.checkCancellation()

            let pois: [POI]
            switch category {
            case .shelters:
                pois = try await fetchShelters(bounds: buffered)
            case .kulturminner:
                pois = try await fetchKulturminner(bounds: buffered)
            default:
                return []
            }

            cache[key] = CacheEntry(pois: pois, timestamp: Date())
            cleanCache()
            return pois
        } catch is CancellationError {
            return cache[key]?.pois ?? []
        } catch let urlError as URLError where urlError.code == .cancelled {
            return cache[key]?.pois ?? []
        } catch {
            #if DEBUG
            print("POI fetch error (\(category.rawValue)): \(error)")
            #endif
            return cache[key]?.pois ?? []
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - DSB Shelters (WFS/GML)

    private func fetchShelters(bounds: ViewportBounds) async throws -> [POI] {
        guard var components = URLComponents(string: "https://ogc.dsb.no/wfs.ashx") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "SERVICE", value: "WFS"),
            URLQueryItem(name: "VERSION", value: "1.1.0"),
            URLQueryItem(name: "REQUEST", value: "GetFeature"),
            URLQueryItem(name: "TYPENAME", value: "layer_340"),
            URLQueryItem(name: "SRSNAME", value: "EPSG:4326"),
            URLQueryItem(name: "BBOX", value: "\(bounds.south),\(bounds.west),\(bounds.north),\(bounds.east),EPSG:4326"),
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

    private func fetchKulturminner(bounds: ViewportBounds) async throws -> [POI] {
        guard var components = URLComponents(string: "https://api.ra.no/brukerminner/collections/brukerminner/items") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "bbox", value: "\(bounds.west),\(bounds.south),\(bounds.east),\(bounds.north)"),
            URLQueryItem(name: "limit", value: "1000"),
        ]

        guard let url = components.url else { return [] }
        let data = try await APIClient.fetchData(
            url: url,
            timeout: Self.poiFetchTimeout,
            additionalHeaders: ["Accept": "application/geo+json"]
        )
        let response = try JSONDecoder().decode(KulturminnerResponse.self, from: data)
        return response.features.compactMap { feature -> POI? in
            guard feature.geometry.type == "Point",
                  feature.geometry.coordinates.count >= 2 else { return nil }

            let lon = feature.geometry.coordinates[0]
            let lat = feature.geometry.coordinates[1]

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

// MARK: - DSB Shelter GML Parser

private class ShelterGMLParser: NSObject, XMLParserDelegate {
    var pois: [POI] = []

    private var currentElement = ""
    private var currentText = ""
    private var inFeature = false
    private var romnr: String?
    private var adresse: String?
    private var plasser: String?
    private var kategori: String?
    private var coordinates: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName.components(separatedBy: ":").last ?? elementName
        currentText = ""

        if currentElement == "featureMember" || currentElement == "member" {
            inFeature = true
            romnr = nil
            adresse = nil
            plasser = nil
            kategori = nil
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
            case "romnr": romnr = text
            case "adresse": adresse = text
            case "plasser": plasser = text
            case "t_kategori": kategori = text
            case "pos": coordinates = text
            default: break
            }
        }

        if name == "featureMember" || name == "member" {
            inFeature = false
            if let coordStr = coordinates {
                // GML pos format: "lat lon"
                let parts = coordStr.split(separator: " ")
                if parts.count >= 2,
                   let lat = Double(parts[0]),
                   let lon = Double(parts[1]) {

                    let id = romnr ?? "\(lat)-\(lon)"
                    let displayName = "Tilfluktsrom \(romnr ?? "")"

                    var details: [String: String] = [:]
                    if let addr = adresse { details["address"] = addr }
                    if let cap = plasser { details["capacity"] = cap }
                    if let kat = kategori { details["category"] = kat }

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
