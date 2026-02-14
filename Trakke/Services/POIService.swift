import Foundation
import CoreLocation

// MARK: - POI Service

actor POIService {
    private var cache: [String: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 1800 // 30 minutes
    private static let maxCacheEntries = 100
    private static let poiFetchTimeout: TimeInterval = 25

    private static let userAgent = "Trakke-iOS/0.1.0 hei@tazk.no"

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
        let key = "\(category.rawValue)-\(buffered.cacheKey)-z\(Int(zoom))"

        if let cached = cache[key], Date().timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            return cached.pois
        }

        do {
            let pois: [POI]
            switch category {
            case .shelters:
                pois = try await fetchShelters(bounds: buffered)
            case .caves:
                pois = try await fetchOverpass(category: .caves, bounds: buffered)
            case .observationTowers:
                pois = try await fetchOverpass(category: .observationTowers, bounds: buffered)
            case .warMemorials:
                pois = try await fetchOverpass(category: .warMemorials, bounds: buffered)
            case .wildernessShelters:
                pois = try await fetchOverpass(category: .wildernessShelters, bounds: buffered)
            case .kulturminner:
                pois = try await fetchKulturminner(bounds: buffered)
            }

            cache[key] = CacheEntry(pois: pois, timestamp: Date())
            cleanCache()
            return pois
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
        var components = URLComponents(string: "https://ogc.dsb.no/wfs.ashx")!
        components.queryItems = [
            URLQueryItem(name: "SERVICE", value: "WFS"),
            URLQueryItem(name: "VERSION", value: "1.1.0"),
            URLQueryItem(name: "REQUEST", value: "GetFeature"),
            URLQueryItem(name: "TYPENAME", value: "layer_340"),
            URLQueryItem(name: "SRSNAME", value: "EPSG:4326"),
            URLQueryItem(name: "BBOX", value: "\(bounds.south),\(bounds.west),\(bounds.north),\(bounds.east),EPSG:4326"),
        ]

        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.poiFetchTimeout
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        return parseShelterGML(data)
    }

    private func parseShelterGML(_ data: Data) -> [POI] {
        let parser = ShelterGMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.pois
    }

    // MARK: - Overpass API

    private func fetchOverpass(category: POICategory, bounds: ViewportBounds) async throws -> [POI] {
        let bbox = "\(bounds.south),\(bounds.west),\(bounds.north),\(bounds.east)"
        let query = overpassQuery(for: category, bbox: bbox)

        let url = URL(string: "https://overpass-api.de/api/interpreter")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.poiFetchTimeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return parseOverpassResponse(response, category: category)
    }

    private func overpassQuery(for category: POICategory, bbox: String) -> String {
        let timeout = "[out:json][timeout:25];"
        let output = "out body;>;out skel qt;"

        switch category {
        case .caves:
            return "\(timeout)(node[\"natural\"=\"cave_entrance\"](\(bbox)););\(output)"
        case .observationTowers:
            return "\(timeout)(node[\"man_made\"=\"tower\"][\"tower:type\"=\"observation\"](\(bbox));way[\"man_made\"=\"tower\"][\"tower:type\"=\"observation\"](\(bbox)););\(output)"
        case .warMemorials:
            return """
            \(timeout)(node["historic"="fort"](\(bbox));way["historic"="fort"](\(bbox));\
            node["military"="bunker"](\(bbox));way["military"="bunker"](\(bbox));\
            node["historic"="bunker"](\(bbox));way["historic"="bunker"](\(bbox));\
            node["historic"="battlefield"](\(bbox)););\(output)
            """
        case .wildernessShelters:
            return """
            \(timeout)(node["amenity"="shelter"]["shelter_type"="basic_hut"](\(bbox));\
            way["amenity"="shelter"]["shelter_type"="basic_hut"](\(bbox));\
            node["amenity"="shelter"]["shelter_type"="weather_shelter"](\(bbox));\
            way["amenity"="shelter"]["shelter_type"="weather_shelter"](\(bbox));\
            node["amenity"="shelter"]["shelter_type"="rock_shelter"](\(bbox));\
            way["amenity"="shelter"]["shelter_type"="rock_shelter"](\(bbox));\
            node["amenity"="shelter"]["shelter_type"="lavvu"](\(bbox));\
            way["amenity"="shelter"]["shelter_type"="lavvu"](\(bbox));\
            node["amenity"="shelter"][!"shelter_type"](\(bbox));\
            way["amenity"="shelter"][!"shelter_type"](\(bbox)););\(output)
            """
        default:
            return ""
        }
    }

    private func parseOverpassResponse(_ response: OverpassResponse, category: POICategory) -> [POI] {
        // Build node coordinate lookup for way centroid calculation
        var nodeMap: [Int: (lat: Double, lon: Double)] = [:]
        for element in response.elements where element.type == "node" {
            if let lat = element.lat, let lon = element.lon {
                nodeMap[element.id] = (lat, lon)
            }
        }

        var seen = Set<Int>()
        var pois: [POI] = []

        for element in response.elements {
            guard !seen.contains(element.id) else { continue }
            guard element.tags != nil else { continue }
            seen.insert(element.id)

            var lat: Double?
            var lon: Double?

            if element.type == "node" {
                lat = element.lat
                lon = element.lon
            } else if element.type == "way", let nodes = element.nodes {
                // Calculate centroid
                let coords = nodes.compactMap { nodeMap[$0] }
                guard !coords.isEmpty else { continue }
                lat = coords.map(\.lat).reduce(0, +) / Double(coords.count)
                lon = coords.map(\.lon).reduce(0, +) / Double(coords.count)
            }

            guard let finalLat = lat, let finalLon = lon else { continue }

            let tags = element.tags ?? [:]
            let poi = makeOverpassPOI(
                id: element.id,
                category: category,
                tags: tags,
                lat: finalLat,
                lon: finalLon
            )
            pois.append(poi)
        }

        return pois
    }

    private func makeOverpassPOI(
        id: Int,
        category: POICategory,
        tags: [String: String],
        lat: Double,
        lon: Double
    ) -> POI {
        let prefix: String
        switch category {
        case .caves: prefix = "cave"
        case .observationTowers: prefix = "tower"
        case .warMemorials: prefix = "memorial"
        case .wildernessShelters: prefix = "wilderness-shelter"
        default: prefix = category.rawValue
        }

        let name = tags["name"] ?? category.displayName

        var details: [String: String] = [:]
        switch category {
        case .caves:
            if let desc = tags["description"] { details["description"] = desc }
        case .observationTowers:
            if let height = tags["height"] { details["height"] = height }
            if let op = tags["operator"] { details["operator"] = op }
        case .warMemorials:
            if let inscription = tags["inscription"] { details["inscription"] = inscription }
            if let period = tags["memorial:period"] { details["period"] = period }
        case .wildernessShelters:
            if let shelterType = tags["shelter_type"] { details["shelterType"] = shelterType }
            if let desc = tags["description"] { details["description"] = desc }
        default:
            break
        }

        return POI(
            id: "\(prefix)-\(id)",
            category: category,
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            details: details
        )
    }

    // MARK: - Riksantikvaren (GeoJSON)

    private func fetchKulturminner(bounds: ViewportBounds) async throws -> [POI] {
        var components = URLComponents(string: "https://api.ra.no/brukerminner/collections/brukerminner/items")!
        components.queryItems = [
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "bbox", value: "\(bounds.west),\(bounds.south),\(bounds.east),\(bounds.north)"),
            URLQueryItem(name: "limit", value: "1000"),
        ]

        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.poiFetchTimeout
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
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

// MARK: - Overpass Response Types

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let nodes: [Int]?
    let tags: [String: String]?
}

// MARK: - Riksantikvaren Response Types

private struct KulturminnerResponse: Decodable {
    let features: [KulturminnerFeature]
}

private struct KulturminnerFeature: Decodable {
    let id: String?
    let geometry: KulturminnerGeometry
    let properties: KulturminnerProperties
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
