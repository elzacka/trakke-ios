#!/usr/bin/env swift
//
// fetch_osm_poi.swift
// Fetches every OpenStreetMap-derived POI category for Tråkke and writes the
// bundled GeoJSON files under ../Trakke/Resources/POIData/.
//
// This script exists because the Overpass queries behind the bundled files used
// to live nowhere. Ten of the seventeen files could not be reproduced, refreshed
// or audited from the repository. The queries are now part of the source.
//
// Two things it must not break:
//
//  1. Non-OSM features are preserved. Bålplasser, teltplasser, rasteplasser and
//     badeplasser mix OSM data with data from UT.no/DNT (and Oslo kommune for
//     badeplasser). DNT closed public access to Nasjonal Turbase, so those
//     records cannot be fetched again — anything whose `source` is not
//     "OpenStreetMap" is carried over from the file on disk untouched.
//  2. Feature ids stay stable. An id is `<prefix>-osm-<type>-<id>`, derived from
//     the OSM element, so the same object keeps its id across refreshes.
//
// Usage:
//   swift fetch_osm_poi.swift                    all categories, from Overpass
//   swift fetch_osm_poi.swift caves viewpoints   named categories only
//   swift fetch_osm_poi.swift --from-cache       reuse Scripts/osm_cache/*.json
//   swift fetch_osm_poi.swift --list             print category names and exit
//
// Raw Overpass responses are cached in Scripts/osm_cache/ so a conversion or
// filter change can be re-run without hitting the API again.

import Foundation

// MARK: - Category definitions

struct OSMCategory {
    let name: String
    let outputFile: String
    let idPrefix: String
    let defaultName: String
    let attribution: String
    /// Overpass statements, unioned into a single request per category.
    let statements: [String]
    /// False for anything that would not belong in the category.
    let keep: ([String: String]) -> Bool
    let properties: ([String: String]) -> [String: String]

    init(
        name: String,
        outputFile: String,
        idPrefix: String,
        defaultName: String,
        attribution: String = "OpenStreetMap contributors (ODbL)",
        statements: [String],
        keep: @escaping ([String: String]) -> Bool = { _ in true },
        properties: @escaping ([String: String]) -> [String: String]
    ) {
        self.name = name
        self.outputFile = outputFile
        self.idPrefix = idPrefix
        self.defaultName = defaultName
        self.attribution = attribution
        self.statements = statements
        self.keep = keep
        self.properties = properties
    }
}

// MARK: - Shared property helpers

/// `description` as the app shows it. OSM's own description wins; otherwise we
/// compose one from the tags a user would want to know before walking there.
/// Values are written in Norwegian — this text goes straight into the UI.
func composedDescription(_ tags: [String: String]) -> String? {
    if let desc = tags["description"], !desc.isEmpty { return desc }

    var parts: [String] = []
    switch tags["access"] {
    case "private": parts.append("Adgang: privat")
    case "customers": parts.append("Adgang: for kunder")
    case "no": parts.append("Adgang: stengt")
    case "destination": parts.append("Adgang: kun for besøkende")
    default: break
    }
    if let surface = tags["surface"], let norwegian = surfaceNames[surface] {
        parts.append("Underlag: \(norwegian)")
    }
    if tags["fireplace"] == "yes" { parts.append("Med bålplass") }
    if tags["bench"] == "yes" { parts.append("Med benk") }
    if tags["drinking_water"] == "yes" { parts.append("Drikkevann") }

    return parts.isEmpty ? nil : parts.joined(separator: ". ")
}

let surfaceNames: [String: String] = [
    "grass": "gress", "gravel": "grus", "sand": "sand", "dirt": "jord",
    "ground": "jord", "earth": "jord", "wood": "tre", "rock": "stein",
    "asphalt": "asfalt", "paved": "fast dekke", "unpaved": "løst dekke",
    "compacted": "komprimert grus", "pebblestone": "singel",
]

func basicProperties(_ tags: [String: String]) -> [String: String] {
    var props: [String: String] = [:]
    if let name = tags["name"] { props["name"] = name }
    if let desc = composedDescription(tags) { props["description"] = desc }
    return props
}

// MARK: - Gapahuk filter
//
// `amenity=shelter` is the tag for any roofed structure you can stand under,
// which in Norway is mostly bus shelters: 1317 of the 5934 features in the old
// wilderness_shelters.geojson were `shelter_type=public_transport`, and the file
// also carried football-pitch dugouts, bicycle parking, changing rooms and a
// shopping-cart shelter — all named «Gapahuk» on the map, because the converter
// applies the default name when OSM has none.
//
// The rules below drop those without dropping minimally tagged real shelters:
// 1052 of the features have `amenity=shelter` and nothing else, and sampling
// them shows genuine outdoor shelters (nature names, `fireplace=yes`, `ele`).
// They are kept.

let shelterTypeDenylist: Set<String> = [
    "public_transport", "changing_rooms", "bicycle_parking", "parking",
    "shopping_cart", "residential", "fire_wood", "sun_shelter", "smoking_area",
    "gazebo", "pavilion", "bomb_shelter", "field_shelter", "animal_shelter",
]

/// Positive signals. Checked before the structural rules, so a real gapahuk
/// tagged `building=roof` is not thrown out with the carports.
let shelterTypeAllowlist: Set<String> = [
    "lean_to", "basic_hut", "rock_shelter", "weather_shelter", "lavvu",
    "turf_hut", "wildlife_hide", "tent", "hut", "kids_hut", "lean_to_boulder",
    "picnic_shelter", "shelter", "building",
]

let urbanBuildings: Set<String> = [
    "roof", "garage", "garages", "carport", "shed", "transportation",
    "residential", "industrial", "service", "retail", "commercial",
    "school", "kindergarten", "apartments", "house",
]

let urbanLeisure: Set<String> = [
    "pitch", "playground", "park", "sports_centre", "stadium", "track",
    "swimming_pool", "fitness_centre", "garden",
]

func keepWildernessShelter(_ tags: [String: String]) -> Bool {
    if let type = tags["shelter_type"], shelterTypeDenylist.contains(type) { return false }
    if tags["tourism"] == "wilderness_hut" { return true }
    if let type = tags["shelter_type"], shelterTypeAllowlist.contains(type) { return true }

    // No shelter_type to go on: reject anything that is part of transport
    // infrastructure, a sports facility or an ordinary building.
    for key in ["highway", "public_transport", "railway", "aeroway"] where tags[key] != nil {
        return false
    }
    if tags["bus"] == "yes" { return false }
    if tags["sport"] != nil { return false }
    if let leisure = tags["leisure"], urbanLeisure.contains(leisure) { return false }
    if let building = tags["building"], urbanBuildings.contains(building) { return false }
    return true
}

// MARK: - Categories

let allCategories: [OSMCategory] = [
    OSMCategory(
        name: "caves",
        outputFile: "caves.geojson",
        idPrefix: "cave",
        defaultName: "Hule",
        statements: ["nwr[\"natural\"=\"cave_entrance\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "viewpoints",
        outputFile: "viewpoints.geojson",
        idPrefix: "viewpoint",
        defaultName: "Utsiktspunkt",
        // `man_made=tower` is deliberately not queried on its own: it would pull
        // in telecom masts. Towers reach this category through tower:type, and
        // the extractor below still classifies the man_made=tower ones.
        statements: [
            "nwr[\"tourism\"=\"viewpoint\"](area.no);",
            "nwr[\"tower:type\"=\"observation\"](area.no);",
            "nwr[\"tower:type\"=\"watchtower\"](area.no);",
            "nwr[\"leisure\"=\"bird_hide\"](area.no);",
        ],
        properties: { tags in
            var props = basicProperties(tags)
            if let ele = tags["ele"] { props["elevation"] = ele }
            if let dir = tags["direction"] { props["direction"] = dir }
            if tags["leisure"] == "bird_hide" {
                props["type"] = "bird_hide"
                if props["name"] == nil { props["name"] = "Fugletårn" }
            } else if tags["tower:type"] == "watchtower" {
                props["type"] = "watchtower"
                if props["name"] == nil { props["name"] = "Vakttårn" }
            } else if tags["tower:type"] == "observation" || tags["man_made"] == "tower" {
                props["type"] = "observation_tower"
                if props["name"] == nil { props["name"] = "Utsiktstårn" }
                if let height = tags["height"] { props["height"] = height }
                if let op = tags["operator"] { props["operator"] = op }
            }
            return props
        }
    ),

    OSMCategory(
        name: "war_memorials",
        outputFile: "war_memorials.geojson",
        idPrefix: "memorial",
        defaultName: "Krigsminne",
        statements: [
            "nwr[\"military\"=\"bunker\"](area.no);",
            "nwr[\"historic\"=\"bunker\"](area.no);",
            "nwr[\"historic\"=\"memorial\"](area.no);",
            "nwr[\"historic\"=\"fort\"](area.no);",
            "nwr[\"historic\"=\"battlefield\"](area.no);",
        ],
        properties: { tags in
            var props = basicProperties(tags)
            if let inscription = tags["inscription"] { props["inscription"] = inscription }
            if let period = tags["memorial:period"] { props["period"] = period }
            if tags["historic"] == "fort" {
                props["type"] = "fort"
            } else if tags["military"] == "bunker" || tags["historic"] == "bunker" {
                props["type"] = "bunker"
            } else if tags["historic"] == "battlefield" {
                props["type"] = "battlefield"
            }
            return props
        }
    ),

    OSMCategory(
        name: "wilderness_shelters",
        outputFile: "wilderness_shelters.geojson",
        idPrefix: "wilderness-shelter",
        defaultName: "Gapahuk",
        statements: [
            "nwr[\"amenity\"=\"shelter\"](area.no);",
            "nwr[\"tourism\"=\"wilderness_hut\"](area.no);",
        ],
        keep: keepWildernessShelter,
        properties: { tags in
            var props = basicProperties(tags)
            if let shelterType = tags["shelter_type"] { props["shelterType"] = shelterType }
            if let ele = tags["ele"] { props["elevation"] = ele }
            if let op = tags["operator"] { props["operator"] = op }
            return props
        }
    ),

    OSMCategory(
        name: "hammocks",
        outputFile: "hammocks.geojson",
        idPrefix: "hammock",
        defaultName: "Hengekøyeplass",
        statements: ["nwr[\"leisure\"=\"hammock\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "fire_pits",
        outputFile: "fire_pits.geojson",
        idPrefix: "firepit",
        defaultName: "Bålplass",
        attribution: "UT.no/DNT, OpenStreetMap contributors (ODbL)",
        statements: ["nwr[\"leisure\"=\"firepit\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "tent_sites",
        outputFile: "tent_sites.geojson",
        idPrefix: "camp",
        defaultName: "Teltplass",
        attribution: "UT.no/DNT, OpenStreetMap contributors (ODbL)",
        // camp_pitch is an individual pitch inside a camp_site and would
        // duplicate the site it belongs to.
        statements: ["nwr[\"tourism\"=\"camp_site\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "rest_areas",
        outputFile: "rest_areas.geojson",
        idPrefix: "rest",
        defaultName: "Rasteplass",
        attribution: "UT.no/DNT, OpenStreetMap contributors (ODbL)",
        statements: [
            "nwr[\"leisure\"=\"picnic_table\"](area.no);",
            "nwr[\"tourism\"=\"picnic_site\"](area.no);",
        ],
        properties: basicProperties
    ),

    OSMCategory(
        name: "swimming_spots",
        outputFile: "swimming_spots.geojson",
        idPrefix: "swimspot",
        defaultName: "Badeplass",
        attribution: "UT.no/DNT, Oslo kommune (Bymiljøetaten/NLOD), OpenStreetMap contributors (ODbL)",
        statements: [
            "nwr[\"leisure\"=\"swimming_area\"](area.no);",
            "nwr[\"sport\"=\"swimming\"](area.no);",
        ],
        // sport=swimming also tags indoor pools and sports centres. A badeplass
        // is somewhere you swim outdoors, so anything inside a building or part
        // of a sports facility is dropped.
        keep: { tags in
            if tags["building"] != nil { return false }
            if let leisure = tags["leisure"],
               ["sports_centre", "swimming_pool", "fitness_centre", "water_park"].contains(leisure) {
                return false
            }
            if tags["access"] == "private" { return false }
            return true
        },
        properties: basicProperties
    ),

    OSMCategory(
        name: "giant_kettles",
        outputFile: "giant_kettles.geojson",
        idPrefix: "kettle",
        defaultName: "Jettegryte",
        statements: ["nwr[\"natural\"=\"giants_kettle\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "oxbow_lakes",
        outputFile: "oxbow_lakes.geojson",
        idPrefix: "oxbow",
        defaultName: "Kroksjø",
        statements: ["nwr[\"water\"=\"oxbow\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "lagoons",
        outputFile: "lagoons.geojson",
        idPrefix: "lagoon",
        defaultName: "Lagune",
        statements: ["nwr[\"water\"=\"lagoon\"](area.no);"],
        properties: basicProperties
    ),

    OSMCategory(
        name: "hot_springs",
        outputFile: "hot_springs.geojson",
        idPrefix: "hotspring",
        defaultName: "Varm kilde",
        statements: ["nwr[\"natural\"=\"hot_spring\"](area.no);"],
        properties: basicProperties
    ),
]

// MARK: - Overpass

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

struct OverpassElement: Decodable {
    struct Coordinate: Decodable {
        let lat: Double
        let lon: Double
    }

    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    /// Present for ways/relations when the query asks for `out center`.
    let center: Coordinate?
    /// Present in the older `out geom` exports kept in Scripts/.
    let geometry: [Coordinate]?
    let tags: [String: String]?

    /// Representative point. Nodes carry it directly; ways and relations get
    /// their centre, or the midpoint of their geometry in the older exports.
    var coordinate: (lat: Double, lon: Double)? {
        if let lat, let lon { return (lat, lon) }
        if let center { return (center.lat, center.lon) }
        if let geometry, !geometry.isEmpty {
            let lat = geometry.reduce(0) { $0 + $1.lat } / Double(geometry.count)
            let lon = geometry.reduce(0) { $0 + $1.lon } / Double(geometry.count)
            return (lat, lon)
        }
        return nil
    }
}

let overpassEndpoints = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

func query(for category: OSMCategory) -> String {
    """
    [out:json][timeout:600];
    area["ISO3166-1"="NO"][admin_level=2]->.no;
    (
    \(category.statements.joined(separator: "\n"))
    );
    out tags center;
    """
}

/// Returns the response body, or a short reason for the log.
func post(_ body: String, to endpoint: String) -> (data: Data?, reason: String?) {
    guard let url = URL(string: endpoint) else { return (nil, "ugyldig endepunkt") }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 900
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    // Overpass answers 406 without a User-Agent it recognises as a client.
    request.setValue("Trakke-POI-fetch/1.0 hei@tazk.no", forHTTPHeaderField: "User-Agent")
    var components = URLComponents()
    components.queryItems = [URLQueryItem(name: "data", value: body)]
    request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

    let semaphore = DispatchSemaphore(value: 0)
    var result: (data: Data?, reason: String?) = (nil, "ingen svar")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let error {
            result = (nil, error.localizedDescription)
            return
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            result = (nil, "HTTP \(http.statusCode)")
            return
        }
        guard let data else {
            result = (nil, "tomt svar")
            return
        }
        result = (data, nil)
    }
    task.resume()
    semaphore.wait()
    return result
}

/// Tries each mirror in turn, twice, before giving up on a category.
func fetchRaw(_ category: OSMCategory) -> Data? {
    let body = query(for: category)
    for round in 1...2 {
        for endpoint in overpassEndpoints {
            let host = URL(string: endpoint)?.host ?? endpoint
            let response = post(body, to: endpoint)
            if let data = response.data { return data }
            print("    \(host): \(response.reason ?? "ukjent feil")")
        }
        if round == 1 {
            print("    venter før nytt forsøk ...")
            Thread.sleep(forTimeInterval: 30)
        }
    }
    return nil
}

// MARK: - Conversion

func round6(_ value: Double) -> Double {
    (value * 1_000_000).rounded() / 1_000_000
}

/// Credits are derived from the `source` values present in the finished file, so
/// a category that gains a source cannot keep an outdated credit line. Same
/// table and order as `fetch_utno_poi.swift` — keep the two in step.
let attributionOrder: [(source: String, credit: String)] = [
    ("UT.no/DNT", "UT.no/DNT"),
    ("UT.no", "UT.no (data fra Statskog, fjellstyrer, kommuner, private m.fl.)"),
    ("Oslo kommune (Bymiljøetaten)", "Oslo kommune (Bymiljøetaten/NLOD)"),
    ("Wikidata", "Wikidata (CC0)"),
    ("OpenStreetMap", "OpenStreetMap contributors (ODbL)"),
]

func attribution(for features: [[String: Any]], fallback: String) -> String {
    let sources = Set(features.compactMap { feature -> String? in
        if let properties = feature["properties"] as? [String: String] { return properties["source"] }
        return (feature["properties"] as? [String: Any])?["source"] as? String
    })
    let credits = attributionOrder
        .filter { sources.contains($0.source) }
        .map(\.credit)
    return credits.isEmpty ? fallback : credits.joined(separator: ", ")
}

// MARK: - Duplicates within OSM
//
// OSM inneholder samme objekt to ganger oftere enn man tror: en gapahuk kan være
// både en node og en bygningsflate, et krigsminne både `historic=memorial` og
// `military=bunker`. Slike par ligger noen få meter fra hverandre med samme navn.
//
// Regelen er derfor streng: samme kilde, innenfor 10 m, og likt navn (eller ett
// av dem bærer bare kategoriens standardnavn). Ved treff beholdes posten med
// mest innhold. En videre regel ville slettet ekte punkter – to bålplasser på
// samme leirplass ligger gjerne 20 m fra hverandre.
//
// Kryssende kilder håndteres i `fetch_utno_poi.swift`, som ser alle kildene
// samtidig. Kvalitetspoengene der må holdes i takt med disse.

let sameSourceRadius: Double = 10

func quality(of properties: [String: String], placeholder: String) -> Int {
    var score = 0
    if let name = properties["name"], !name.isEmpty, name != placeholder { score += 3 }
    if let description = properties["description"], description.count > 10 { score += 2 }
    if properties["elevation"] != nil { score += 1 }
    let extras = ["shelterType", "operator", "owner", "type", "height"]
    score += min(3, extras.filter { properties[$0] != nil }.count)
    return score
}

func metres(_ a: (lon: Double, lat: Double), _ b: (lon: Double, lat: Double)) -> Double {
    let meanLatitude = ((a.lat + b.lat) / 2) * .pi / 180
    let x = (b.lon - a.lon) * cos(meanLatitude) * 111_320
    let y = (b.lat - a.lat) * 111_320
    return (x * x + y * y).squareRoot()
}

/// Fjerner dubletter innenfor samme kilde. Beholder den beste i hvert par, og
/// velger på id ved likt innhold, slik at to kjøringer gir samme fil.
func removeSameSourceDuplicates(
    _ features: [[String: Any]],
    placeholder: String
) -> (kept: [[String: Any]], dropped: Int) {
    var points: [(lon: Double, lat: Double)?] = []
    var grid: [String: [Int]] = [:]
    let cell = 0.002
    for (index, feature) in features.enumerated() {
        guard let geometry = feature["geometry"] as? [String: Any],
              let raw = geometry["coordinates"] as? [Double], raw.count >= 2 else {
            points.append(nil)
            continue
        }
        let point = (lon: raw[0], lat: raw[1])
        points.append(point)
        grid["\(Int((point.lon / cell).rounded(.down)))|\(Int((point.lat / cell).rounded(.down)))",
            default: []].append(index)
    }

    func properties(_ index: Int) -> [String: String] {
        features[index]["properties"] as? [String: String] ?? [:]
    }

    var drop = Set<Int>()
    for (index, point) in points.enumerated() {
        guard let point, !drop.contains(index) else { continue }
        let cx = Int((point.lon / cell).rounded(.down))
        let cy = Int((point.lat / cell).rounded(.down))
        for dx in -1...1 {
            for dy in -1...1 {
                for other in grid["\(cx + dx)|\(cy + dy)"] ?? []
                where other > index && !drop.contains(other) {
                    guard let otherPoint = points[other],
                          metres(point, otherPoint) <= sameSourceRadius else { continue }
                    let a = properties(index)["name"] ?? ""
                    let b = properties(other)["name"] ?? ""
                    guard a == b || a == placeholder || b == placeholder else { continue }

                    let qa = quality(of: properties(index), placeholder: placeholder)
                    let qb = quality(of: properties(other), placeholder: placeholder)
                    let idA = features[index]["id"] as? String ?? ""
                    let idB = features[other]["id"] as? String ?? ""
                    if qb > qa || (qb == qa && idB < idA) {
                        drop.insert(index)
                    } else {
                        drop.insert(other)
                    }
                }
            }
        }
    }

    return (features.indices.filter { !drop.contains($0) }.map { features[$0] }, drop.count)
}

/// Builds the GeoJSON features for one category from an Overpass response.
func convert(_ data: Data, category: OSMCategory) -> (features: [[String: Any]], dropped: Int)? {
    guard let response = try? JSONDecoder().decode(OverpassResponse.self, from: data) else {
        return nil
    }

    var seen = Set<String>()
    var features: [[String: Any]] = []
    var dropped = 0

    for element in response.elements {
        guard let tags = element.tags, !tags.isEmpty else { continue }
        guard let point = element.coordinate,
              point.lat.isFinite, point.lon.isFinite,
              (-90...90).contains(point.lat), (-180...180).contains(point.lon) else { continue }

        let reference = "\(element.type)-\(element.id)"
        guard seen.insert(reference).inserted else { continue }

        guard category.keep(tags) else {
            dropped += 1
            continue
        }

        var properties = category.properties(tags)
        if properties["name"] == nil { properties["name"] = category.defaultName }
        properties["source"] = "OpenStreetMap"
        properties["osm_ref"] = reference

        features.append([
            "type": "Feature",
            "id": "\(category.idPrefix)-osm-\(reference)",
            "geometry": [
                "type": "Point",
                "coordinates": [round6(point.lon), round6(point.lat)],
            ] as [String: Any],
            "properties": properties,
        ])
    }

    return (features, dropped)
}

// MARK: - Paths

let scriptDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Trakke/Resources/POIData")
let cacheDir = scriptDir.appendingPathComponent("osm_cache")

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())
let listOnly = arguments.contains("--list")
let fromCache = arguments.contains("--from-cache")
arguments.removeAll { $0.hasPrefix("--") }

if listOnly {
    for category in allCategories { print(category.name) }
    exit(0)
}

let selected: [OSMCategory]
if arguments.isEmpty {
    selected = allCategories
} else {
    let unknown = arguments.filter { name in !allCategories.contains { $0.name == name } }
    if !unknown.isEmpty {
        print("Ukjente kategorier: \(unknown.joined(separator: ", "))")
        print("Gyldige navn: \(allCategories.map(\.name).joined(separator: ", "))")
        exit(1)
    }
    selected = allCategories.filter { arguments.contains($0.name) }
}

try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

// MARK: - Run

let timestamp = ISO8601DateFormatter().string(from: Date())
var failures: [String] = []

for category in selected {
    print("\(category.name):")
    let cachePath = cacheDir.appendingPathComponent("\(category.name).json")

    let raw: Data?
    if fromCache {
        raw = try? Data(contentsOf: cachePath)
        if raw == nil { print("    ingen cache i \(cachePath.lastPathComponent)") }
    } else {
        raw = fetchRaw(category)
        if let raw { try? raw.write(to: cachePath) }
    }

    guard let raw else {
        failures.append(category.name)
        continue
    }

    guard let converted = convert(raw, category: category) else {
        print("    klarte ikke å dekode Overpass-svaret")
        failures.append(category.name)
        continue
    }

    // Anything not from OSM is kept as it stands — see the note at the top.
    let outputPath = outputDir.appendingPathComponent(category.outputFile)
    var preserved: [[String: Any]] = []
    var previousOSM = Set<String>()
    if let existing = try? Data(contentsOf: outputPath),
       let json = try? JSONSerialization.jsonObject(with: existing) as? [String: Any],
       let features = json["features"] as? [[String: Any]] {
        for feature in features {
            let properties = feature["properties"] as? [String: Any]
            // A missing `source` means OSM: the four files this script took over
            // from convert_overpass.swift were written without one. Preserving
            // them would duplicate every feature the fetch re-adds.
            let source = properties?["source"] as? String ?? "OpenStreetMap"
            if source == "OpenStreetMap" {
                if let reference = properties?["osm_ref"] as? String { previousOSM.insert(reference) }
            } else {
                preserved.append(feature)
            }
        }
    }

    let (osmFeatures, sameSourceDuplicates) = removeSameSourceDuplicates(
        converted.features, placeholder: category.defaultName
    )

    let currentOSM = Set(osmFeatures.compactMap {
        ($0["properties"] as? [String: String])?["osm_ref"]
    })
    let added = currentOSM.subtracting(previousOSM).count
    let removed = previousOSM.subtracting(currentOSM).count

    let all = (preserved + osmFeatures).sorted {
        ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "")
    }

    let collection: [String: Any] = [
        "type": "FeatureCollection",
        "generator": "Trakke fetch_osm_poi.swift",
        "attribution": attribution(for: all, fallback: category.attribution),
        "timestamp": timestamp,
        "features": all,
    ]

    guard let output = try? JSONSerialization.data(withJSONObject: collection, options: [.sortedKeys]) else {
        print("    klarte ikke å kode GeoJSON")
        failures.append(category.name)
        continue
    }

    do {
        try output.write(to: outputPath)
    } catch {
        print("    klarte ikke å skrive \(category.outputFile): \(error)")
        failures.append(category.name)
        continue
    }

    var line = "    \(all.count) totalt"
    line += " (\(osmFeatures.count) fra OSM"
    if !preserved.isEmpty { line += ", \(preserved.count) bevart fra andre kilder" }
    line += ")"
    print(line)
    if converted.dropped > 0 { print("    \(converted.dropped) filtrert bort") }
    if sameSourceDuplicates > 0 { print("    \(sameSourceDuplicates) dubletter i OSM fjernet") }
    if !previousOSM.isEmpty { print("    OSM-endring: +\(added) nye, -\(removed) borte") }
    print("    \(String(format: "%.1f", Double(output.count) / 1024.0)) KB")

    if !fromCache, category.name != selected.last?.name {
        Thread.sleep(forTimeInterval: 5)
    }
}

if failures.isEmpty {
    print("Ferdig.")
} else {
    print("Feilet: \(failures.joined(separator: ", ")) — filene er urørt.")
    exit(1)
}
