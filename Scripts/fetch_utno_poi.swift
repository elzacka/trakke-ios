#!/usr/bin/env swift
//
// fetch_utno_poi.swift
// Fetches POIs and cabins from UT.no (Nasjonal Turbase) and merges them into the
// bundled GeoJSON files under ../Trakke/Resources/POIData/.
//
// WHY THIS GOES THROUGH ut.no AND NOT api.nasjonalturbase.no
//
// DNT closed public access to Nasjonal Turbase — api.nasjonalturbase.no now
// returns a bare 404 on every path, and hjelp.ut.no states the open access had
// to be shut down after technical changes. The UT.no web map still reads the
// same data through a Next.js proxy at https://ut.no/api/graphql, which holds
// the credential server-side; api.ut.no itself answers "Forbidden resource"
// without a token. That proxy is what this script uses.
//
// Two consequences to be aware of:
//  - This is an undocumented internal endpoint. It can change or close without
//    notice. The script fails loudly and leaves the files untouched when it does.
//  - The data is no longer published as open data. Redistribution rests on
//    DNT's permission, not on a licence — confirm before shipping a build that
//    adds materially more UT.no data than 1.7.3 already carries.
//
// RUN ORDER: fetch_osm_poi.swift first, then this script. Categories that hold
// both sources (badeplasser, bålplasser, rasteplasser, teltplasser, gapahuker,
// utsiktspunkter, huler) are deduplicated here, and the OSM script rebuilds its
// own portion from scratch — so running them the other way round leaves the
// duplicates in.
//
// Usage:
//   swift fetch_utno_poi.swift               everything
//   swift fetch_utno_poi.swift --list        print target files and exit
//   swift fetch_utno_poi.swift --from-cache  reuse Scripts/utno_cache/*.json

import Foundation

// MARK: - GraphQL client

let graphqlURL = URL(string: "https://ut.no/api/graphql")!

func graphql(_ query: String, variables: [String: Any] = [:]) -> [String: Any]? {
    var request = URLRequest(url: graphqlURL)
    request.httpMethod = "POST"
    request.timeoutInterval = 120
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Identify the script honestly. A browser User-Agent was used while finding
    // the endpoint; the proxy turns out not to require one, and pretending to be
    // Chrome would hide who is calling from whoever runs the service.
    request.setValue("Trakke-POI-fetch/1.0 hei@tazk.no", forHTTPHeaderField: "User-Agent")
    request.httpBody = try? JSONSerialization.data(
        withJSONObject: ["query": query, "variables": variables]
    )

    for attempt in 1...4 {
        let semaphore = DispatchSemaphore(value: 0)
        var payload: Data?
        var problem: String?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error { problem = error.localizedDescription; return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                problem = "HTTP \(http.statusCode)"
                return
            }
            payload = data
        }
        task.resume()
        semaphore.wait()

        if let payload,
           let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
            if let errors = json["errors"] {
                problem = String(describing: errors).prefix(240).description
            } else if let data = json["data"] as? [String: Any] {
                return data
            }
        }
        print("    forsøk \(attempt): \(problem ?? "uleselig svar")")
        Thread.sleep(forTimeInterval: Double(attempt) * 5)
    }
    return nil
}

/// Pages a Relay-style connection to the end.
func fetchAll(query: String, connection: String) -> [[String: Any]]? {
    var nodes: [[String: Any]] = []
    var cursor: String?
    var total = 0

    while true {
        var variables: [String: Any] = ["first": 500]
        if let cursor { variables["after"] = cursor }
        guard let data = graphql(query, variables: variables),
              let page = data[connection] as? [String: Any],
              let edges = page["edges"] as? [[String: Any]],
              let pageInfo = page["pageInfo"] as? [String: Any] else {
            return nil
        }
        total = page["totalCount"] as? Int ?? total
        nodes.append(contentsOf: edges.compactMap { $0["node"] as? [String: Any] })
        print("    \(nodes.count)/\(total)")

        guard pageInfo["hasNextPage"] as? Bool == true,
              let next = pageInfo["endCursor"] as? String else { break }
        cursor = next
        Thread.sleep(forTimeInterval: 1)
    }
    return nodes
}

// `after` is a ConnectionCursor, not a String — declaring it as String fails
// GraphQL validation with 400.
let poiQuery = """
query($first: Int!, $after: ConnectionCursor) {
  pois(paging: { first: $first, after: $after }) {
    totalCount
    pageInfo { hasNextPage endCursor }
    edges { node {
      id name primaryTypeName secondaryTypes { name } description geojson status
    } }
  }
}
"""

let cabinQuery = """
query($first: Int!, $after: ConnectionCursor) {
  cabins(paging: { first: $first, after: $after }) {
    totalCount
    pageInfo { hasNextPage endCursor }
    edges { node {
      id name description serviceLevel dntCabin geojson status
      bedsStaffed bedsSelfService bedsNoService
      ownerGroupConnection { name }
    } }
  }
}
"""

// MARK: - Text handling

/// UT.no serves HTML. Cabin descriptions are long articles with `<h2>` sections;
/// only the lead is useful in a map popup, and it is capped the same way the
/// bundled files already are (240 characters plus an ellipsis).
func plainText(_ html: String, leadOnly: Bool) -> String? {
    var text = html
    if leadOnly, let cut = text.range(of: "<h2", options: .caseInsensitive) {
        text = String(text[text.startIndex..<cut.lowerBound])
    }
    text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    text = text
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
    text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !text.isEmpty else { return nil }
    guard text.count > 240 else { return text }
    return String(text.prefix(240)) + "..."
}

let serviceLevelNames: [String: String] = [
    "STAFFED": "Betjent",
    "SELF_SERVICE": "Selvbetjent",
    "NO_SERVICE": "Ubetjent",
    "NO_SERVICE_NO_BEDS": "Dagsturhytte",
    "RENTAL": "Utleiehytte",
    "FOOD_SERVICE": "Servering",
    "EMERGENCY_SHELTER": "Nødbu",
    "CLOSED": "Stengt",
]

// MARK: - Targets

/// One bundled file, and which UT.no POI type feeds it.
struct Target {
    let poiType: String
    let outputFile: String
    let idPrefix: String
    /// Generic name the OSM converter falls back to. A UT.no record that
    /// duplicates an OSM feature carrying only this placeholder name wins, since
    /// it has the real name and a description; anything else keeps its OSM id.
    let osmPlaceholder: String?
}

let targets: [Target] = [
    // Categories that already existed and only gain UT.no records.
    Target(poiType: "bathing spot", outputFile: "swimming_spots.geojson", idPrefix: "swimspot-ut-", osmPlaceholder: "Badeplass"),
    Target(poiType: "fireplace", outputFile: "fire_pits.geojson", idPrefix: "firepit-ut-", osmPlaceholder: "Bålplass"),
    Target(poiType: "picnic area", outputFile: "rest_areas.geojson", idPrefix: "rest-ut-", osmPlaceholder: "Rasteplass"),
    Target(poiType: "campground", outputFile: "tent_sites.geojson", idPrefix: "camp-ut-", osmPlaceholder: "Teltplass"),
    Target(poiType: "shelter", outputFile: "wilderness_shelters.geojson", idPrefix: "wilderness-shelter-ut-", osmPlaceholder: "Gapahuk"),
    Target(poiType: "lookout point", outputFile: "viewpoints.geojson", idPrefix: "viewpoint-ut-", osmPlaceholder: "Utsiktspunkt"),
    Target(poiType: "grotto", outputFile: "caves.geojson", idPrefix: "cave-ut-", osmPlaceholder: "Hule"),

    // Setre, stølar and dagsturhytter that are not in the cabin registry. Own
    // file rather than andre_hytter.geojson, whose UT.no portion is owned by the
    // cabin pass below.
    Target(poiType: "hut", outputFile: "setre.geojson", idPrefix: "setr-ut-", osmPlaceholder: nil),

    // Categories introduced with this data.
    Target(poiType: "bridge", outputFile: "bridges.geojson", idPrefix: "bridge-ut-", osmPlaceholder: nil),
    Target(poiType: "fording place", outputFile: "fording_places.geojson", idPrefix: "ford-ut-", osmPlaceholder: nil),
    Target(poiType: "parking", outputFile: "parking.geojson", idPrefix: "parking-ut-", osmPlaceholder: nil),
    Target(poiType: "sign point", outputFile: "sign_points.geojson", idPrefix: "signpost-ut-", osmPlaceholder: nil),
    Target(poiType: "toilet", outputFile: "toilets.geojson", idPrefix: "toilet-ut-", osmPlaceholder: nil),
    Target(poiType: "food service", outputFile: "food_services.geojson", idPrefix: "food-ut-", osmPlaceholder: nil),
    Target(poiType: "recreation_area", outputFile: "recreation_areas.geojson", idPrefix: "recreation-ut-", osmPlaceholder: nil),
    Target(poiType: "fishing", outputFile: "fishing_spots.geojson", idPrefix: "fishing-ut-", osmPlaceholder: nil),
    Target(poiType: "climbing", outputFile: "climbing_spots.geojson", idPrefix: "climbing-ut-", osmPlaceholder: nil),
    Target(poiType: "sledding hill", outputFile: "sledding_hills.geojson", idPrefix: "sledding-ut-", osmPlaceholder: nil),
    Target(poiType: "ski lift", outputFile: "ski_lifts.geojson", idPrefix: "skilift-ut-", osmPlaceholder: nil),
    Target(poiType: "trip record", outputFile: "trip_records.geojson", idPrefix: "triprecord-ut-", osmPlaceholder: nil),

    // Fjelltopper går inn i utsiktspunkter. En topp *er* et utsiktspunkt, og som
    // egen kategori doblet de 1808 toppene seg mot 4300 OSM-utsiktspunkter med
    // reelt overlapp. Dedupliseringen rydder overlappet.
    Target(poiType: "mountain peak", outputFile: "viewpoints.geojson", idPrefix: "peak-ut-", osmPlaceholder: "Utsiktspunkt"),

    Target(poiType: "cultural heritage", outputFile: "kulturminner_utno.geojson", idPrefix: "heritage-ut-", osmPlaceholder: nil),
    // Pseudotype: severdigheter som i praksis er krigsminner. Se `effectiveType`.
    Target(poiType: "war memorial", outputFile: "war_memorials.geojson", idPrefix: "memorial-ut-", osmPlaceholder: "Krigsminne"),
    Target(poiType: "attraction", outputFile: "attractions.geojson", idPrefix: "attraction-ut-", osmPlaceholder: nil),
]

// MARK: - Sorting attractions
//
// «attraction» is UT.no's catch-all and spans a porcelain factory, a city
// swimming hall, a quotation stone on a pavement walk, an ancient pine and a
// waterfall. Only what belongs on a trip in nature should reach the map, so the
// type is resolved in two steps.
//
// First: UT.no's own secondary types decide. An attraction also tagged
// «bathing spot» or «cultural heritage» is exactly that, and lands in the
// category the user already knows — which is also how the porcelain factory
// leaves Severdigheter without a single keyword being involved.
//
// Only what has no more specific type left meets the name filter below.

let targetTypes: [String] = targets.map(\.poiType)

/// Names that place something in a town rather than on a trip. Matched against
/// the name only: descriptions mention city names in passing, and matching those
/// threw out genuine nature targets.
let urbanNameMarkers: [String] = [
    "sitatstein", "ytringsfrihetstur", "statue", "byste", "skulptur",
    "museum", "museet", "besøkssenter", "kino", "bibliotek", "rådhus",
    "kjøpesenter", "senteret", "fabrikk", "industri", "kraftverk",
    "bybad", "badeland", "svømmehall", "idrettshall", "stadion",
    "kirke", "kirka", "kyrkje", "domkirke", "kapell", "katedral",
    "bygdetun", "aktivitetspark", "lekeplass", "barnehage", "skole",
    "gravlund", "kirkegård", "rundkjøring", "torg", "bykultur",
    "pumptrack", "domen", "parken",
]

/// «parken» catches town parks, but a national or nature park is somewhere you
/// actually go on a trip.
let parkExceptions: [String] = ["nasjonalpark", "naturpark", "landskapspark", "friluftspark"]

func isUrbanAttraction(name: String) -> Bool {
    let lowercased = name.lowercased()
    if parkExceptions.contains(where: { lowercased.contains($0) }) { return false }
    return urbanNameMarkers.contains { lowercased.contains($0) }
}

// Mange severdigheter er i praksis krigsminner eller kulturminner. Navnet er den
// presise kilden; beskrivelsen brukes bare for uttrykk som ikke kan bety noe
// annet. Kulturminne-uttrykk i beskrivelsen er utelatt med vilje: «Rett i
// nærheten ligger en gravrøys» gjorde et geografisk midtpunkt til et kulturminne.
let warNamePattern = try! NSRegularExpression(
    pattern: "bunker|festning|\\bfort\\b|batteri|skanse|kanon|krigsmin|fangeleir"
        + "|flyvrak|kystfort|antiluftskyts|ammunisjon|løpegrav|skyttergrav",
    options: .caseInsensitive
)
// Bare uttrykk som sier at *objektet* er militært. «2. verdenskrig» alene var
// for løst: det gjorde en lokomobil, et vanntårn og en sitatstein til
// krigsminner, fordi beskrivelsene nevner krigen i forbifarten.
let warDescriptionPattern = try! NSRegularExpression(
    pattern: "krigsminne|kystfort|fangeleir|tyskerne bygde|tyske soldater bygde"
        + "|minnesmerke fra 2\\. verdenskrig|minnesmerke fra andre verdenskrig",
    options: .caseInsensitive
)
let heritageNamePattern = try! NSRegularExpression(
    pattern: "ruin|husmannsplass|gravrøys|gravhaug|gravfelt|bergkunst|helleristning"
        + "|stavkirk|kirkeruin|fangstgrop|bygdeborg|\\btuft|mølle|sagbruk|kalkovn"
        + "|jernvinn|steinsetting|kullmile|tjæremile|hulveg",
    options: .caseInsensitive
)
let heritageDescriptionPattern = try! NSRegularExpression(
    pattern: "automatisk fredet|fredet kulturminne",
    options: .caseInsensitive
)

func matches(_ pattern: NSRegularExpression, _ text: String) -> Bool {
    guard !text.isEmpty else { return false }
    return pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
}

/// The category a POI belongs in, or nil when it is dropped.
func effectiveType(of node: [String: Any]) -> String? {
    guard let primary = node["primaryTypeName"] as? String else { return nil }
    guard primary == "attraction" else { return primary }

    let secondary = Set((node["secondaryTypes"] as? [[String: Any]] ?? [])
        .compactMap { $0["name"] as? String })
    // Ordered by the target list, so the choice never depends on the order the
    // API happened to return the secondary types in.
    if let mapped = targetTypes.first(where: {
        $0 != "attraction" && $0 != "war memorial" && secondary.contains($0)
    }) {
        return mapped
    }

    // Bymål lukes ut først. En sitatstein er et byobjekt uansett hva
    // beskrivelsen nevner, og slapp gjennom da krigsfiltreringen kom først.
    let name = node["name"] as? String ?? ""
    if isUrbanAttraction(name: name) { return nil }

    let description = node["description"] as? String ?? ""
    if matches(warNamePattern, name) || matches(warDescriptionPattern, description) {
        return "war memorial"
    }
    if matches(heritageNamePattern, name) || matches(heritageDescriptionPattern, description) {
        return "cultural heritage"
    }
    return "attraction"
}

struct CabinTarget {
    let dntCabin: Bool
    let outputFile: String
    let idPrefix: String
    let source: String
    let attribution: String
    let includeOwner: Bool
}

let cabinTargets: [CabinTarget] = [
    CabinTarget(
        dntCabin: true, outputFile: "dnt_hytter.geojson", idPrefix: "dnthut-",
        source: "UT.no/DNT", attribution: "UT.no/DNT", includeOwner: false
    ),
    CabinTarget(
        dntCabin: false, outputFile: "andre_hytter.geojson", idPrefix: "hut-",
        source: "UT.no",
        attribution: "UT.no (data fra Statskog, fjellstyrer, kommuner, private m.fl.)",
        includeOwner: true
    ),
]

// MARK: - Geometry

func coordinates(from node: [String: Any]) -> (lon: Double, lat: Double, elevation: Int?)? {
    guard let geojson = node["geojson"] as? [String: Any],
          let raw = geojson["coordinates"] as? [Any],
          raw.count >= 2,
          let lon = raw[0] as? Double, let lat = raw[1] as? Double,
          lon.isFinite, lat.isFinite,
          (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
    var elevation: Int?
    if raw.count >= 3, let value = raw[2] as? Double, value.isFinite, value > 0 {
        elevation = Int(value.rounded())
    }
    return (lon, lat, elevation)
}

func round6(_ value: Double) -> Double {
    (value * 1_000_000).rounded() / 1_000_000
}

/// Metres between two coordinates. Equirectangular is accurate enough at the
/// 50 m scale this is used for.
func metres(_ a: (lon: Double, lat: Double), _ b: (lon: Double, lat: Double)) -> Double {
    let meanLatitude = ((a.lat + b.lat) / 2) * .pi / 180
    let x = (b.lon - a.lon) * cos(meanLatitude) * 111_320
    let y = (b.lat - a.lat) * 111_320
    return (x * x + y * y).squareRoot()
}

// MARK: - Duplicates
//
// Ved dublett vinner posten med best datakvalitet, ikke den som lå der først.
// Poengene måler hva en bruker faktisk får se i detaljarket.
//
// Radiusen er ulik med vilje. To poster fra *ulike* registre innenfor 50 m er
// nesten alltid samme sted beskrevet to ganger. To poster fra *samme* register
// er nesten alltid to virkelige objekter – to bålplasser på samme leirplass,
// to rasteplasser langs samme sti – så der kreves 10 m og likt navn før de
// regnes som samme sted. Uten det skillet ville en blank 50 m-regel slettet
// ekte punkter i tette kategorier som rasteplasser (9000 poster).

let crossSourceRadius: Double = 50
let sameSourceRadius: Double = 10

/// Rangering når to poster har like mange kvalitetspoeng. UT.no/DNT er
/// redaksjonelt vedlikeholdt med norske beskrivelser; OSM varierer mest.
func sourceRank(_ source: String) -> Int {
    if source.hasPrefix("UT.no") { return 3 }
    if source.hasPrefix("Oslo kommune") { return 2 }
    return 1
}

func quality(of feature: [String: Any], placeholder: String?) -> Int {
    guard let properties = feature["properties"] as? [String: Any] else { return 0 }
    var score = 0

    // Et eget navn er det mest verdifulle enkeltfeltet. Kategoriens
    // standardnavn («Gapahuk», «Utsiktspunkt») teller ikke – det er bare et
    // fyllord konverteringen setter inn når kilden mangler navn.
    if let name = properties["name"] as? String, !name.isEmpty, name != placeholder {
        score += 3
    }
    if let description = properties["description"] as? String, description.count > 10 { score += 2 }
    if properties["elevation"] != nil { score += 1 }

    // Strukturerte felter som sier noe konkret om stedet.
    let extras = ["shelterType", "operator", "owner", "beds", "capacity", "type", "height"]
    score += min(3, extras.filter { properties[$0] != nil }.count)
    return score
}

func source(of feature: [String: Any]) -> String {
    ((feature["properties"] as? [String: Any])?["source"] as? String) ?? "OpenStreetMap"
}

func name(of feature: [String: Any]) -> String {
    (((feature["properties"] as? [String: Any])?["name"] as? String) ?? "")
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func coordinate(of feature: [String: Any]) -> (lon: Double, lat: Double)? {
    guard let geometry = feature["geometry"] as? [String: Any],
          let raw = geometry["coordinates"] as? [Any], raw.count >= 2,
          let lon = raw[0] as? Double, let lat = raw[1] as? Double else { return nil }
    return (lon, lat)
}

/// Beholder én post per klynge av dubletter. Klyngene bygges med union-find, så
/// resultatet ikke avhenger av rekkefølgen postene kommer inn i – og dermed blir
/// likt om skriptet kjøres to ganger.
func deduplicate(
    _ features: [[String: Any]],
    placeholder: String?
) -> (kept: [[String: Any]], dropped: [(loser: String, winner: String)]) {
    guard features.count > 1 else { return (features, []) }

    var parent = Array(0..<features.count)
    func root(_ i: Int) -> Int {
        var i = i
        while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
        return i
    }
    func union(_ a: Int, _ b: Int) {
        let (ra, rb) = (root(a), root(b))
        if ra != rb { parent[max(ra, rb)] = min(ra, rb) }
    }

    let cell = 0.002
    var grid: [String: [Int]] = [:]
    var points = [(lon: Double, lat: Double)?](repeating: nil, count: features.count)
    for (index, feature) in features.enumerated() {
        guard let point = coordinate(of: feature) else { continue }
        points[index] = point
        let key = "\(Int((point.lon / cell).rounded(.down)))|\(Int((point.lat / cell).rounded(.down)))"
        grid[key, default: []].append(index)
    }

    for (index, point) in points.enumerated() {
        guard let point else { continue }
        let cx = Int((point.lon / cell).rounded(.down))
        let cy = Int((point.lat / cell).rounded(.down))
        for dx in -1...1 {
            for dy in -1...1 {
                for other in grid["\(cx + dx)|\(cy + dy)"] ?? [] where other > index {
                    guard let otherPoint = points[other] else { continue }
                    let distance = metres(point, otherPoint)
                    let sameSource = source(of: features[index]) == source(of: features[other])
                    if sameSource {
                        guard distance <= sameSourceRadius else { continue }
                        // Samme register: bare når det tydelig er samme objekt.
                        let a = name(of: features[index])
                        let b = name(of: features[other])
                        let placeholderName = placeholder?.lowercased()
                        let sameObject = a == b || a == placeholderName || b == placeholderName
                        guard sameObject else { continue }
                    } else {
                        guard distance <= crossSourceRadius else { continue }
                    }
                    union(index, other)
                }
            }
        }
    }

    var clusters: [Int: [Int]] = [:]
    for index in features.indices { clusters[root(index), default: []].append(index) }

    var keep = Set<Int>()
    var dropped: [(String, String)] = []
    for (_, members) in clusters {
        guard members.count > 1 else { keep.insert(members[0]); continue }
        let ranked = members.sorted { lhs, rhs in
            let ql = quality(of: features[lhs], placeholder: placeholder)
            let qr = quality(of: features[rhs], placeholder: placeholder)
            if ql != qr { return ql > qr }
            let sl = sourceRank(source(of: features[lhs]))
            let sr = sourceRank(source(of: features[rhs]))
            if sl != sr { return sl > sr }
            // Siste kriterium: id, slik at valget er det samme hver kjøring.
            return (features[lhs]["id"] as? String ?? "") < (features[rhs]["id"] as? String ?? "")
        }
        keep.insert(ranked[0])
        let winner = features[ranked[0]]["id"] as? String ?? "?"
        for loser in ranked.dropFirst() {
            dropped.append((features[loser]["id"] as? String ?? "?", winner))
        }
    }

    return (features.indices.filter { keep.contains($0) }.map { features[$0] }, dropped)
}

// MARK: - Paths

let scriptDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Trakke/Resources/POIData")
let cacheDir = scriptDir.appendingPathComponent("utno_cache")

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("--list") {
    for target in targets { print("\(target.poiType) -> \(target.outputFile)") }
    for target in cabinTargets { print("cabins(dnt: \(target.dntCabin)) -> \(target.outputFile)") }
    exit(0)
}
let fromCache = arguments.contains("--from-cache")

try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

// MARK: - Fetch

func loadCached(_ name: String) -> [[String: Any]]? {
    let path = cacheDir.appendingPathComponent("\(name).json")
    guard let data = try? Data(contentsOf: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return nil
    }
    return json
}

func store(_ nodes: [[String: Any]], as name: String) {
    guard let data = try? JSONSerialization.data(withJSONObject: nodes) else { return }
    try? data.write(to: cacheDir.appendingPathComponent("\(name).json"))
}

let poiNodes: [[String: Any]]
let cabinNodes: [[String: Any]]

if fromCache {
    guard let pois = loadCached("pois"), let cabins = loadCached("cabins") else {
        print("Mangler cache i \(cacheDir.path). Kjør uten --from-cache først.")
        exit(1)
    }
    poiNodes = pois
    cabinNodes = cabins
    print("Leser fra cache: \(pois.count) POI-er, \(cabins.count) hytter")
} else {
    print("Henter POI-er fra UT.no ...")
    guard let pois = fetchAll(query: poiQuery, connection: "pois") else {
        print("Klarte ikke å hente POI-er. Filene er urørt.")
        exit(1)
    }
    print("Henter hytter fra UT.no ...")
    guard let cabins = fetchAll(query: cabinQuery, connection: "cabins") else {
        print("Klarte ikke å hente hytter. Filene er urørt.")
        exit(1)
    }
    poiNodes = pois
    cabinNodes = cabins
    store(pois, as: "pois")
    store(cabins, as: "cabins")
}

// MARK: - Merge helpers

/// Splits an existing file into the UT.no part (to be replaced) and everything
/// else (to be kept). `source` is the discriminator; ids are only a fallback.
func readExisting(_ file: String, idPrefix: String) -> (kept: [[String: Any]], previousUTIds: Set<String>) {
    let path = outputDir.appendingPathComponent(file)
    guard let data = try? Data(contentsOf: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let features = json["features"] as? [[String: Any]] else {
        return ([], [])
    }

    var kept: [[String: Any]] = []
    var previous = Set<String>()
    for feature in features {
        let properties = feature["properties"] as? [String: Any]
        let source = properties?["source"] as? String ?? ""
        let id = feature["id"] as? String ?? ""
        if source.hasPrefix("UT.no") || id.hasPrefix(idPrefix) {
            previous.insert(id)
        } else {
            kept.append(feature)
        }
    }
    return (kept, previous)
}

func write(_ features: [[String: Any]], to file: String, attribution: String, timestamp: String) -> Int? {
    let sorted = features.sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    let collection: [String: Any] = [
        "type": "FeatureCollection",
        "generator": "Trakke fetch_utno_poi.swift",
        "attribution": attribution,
        "timestamp": timestamp,
        "features": sorted,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: collection, options: [.sortedKeys]) else {
        return nil
    }
    do {
        try data.write(to: outputDir.appendingPathComponent(file))
        return data.count
    } catch {
        print("    klarte ikke å skrive \(file): \(error)")
        return nil
    }
}

/// Credits are derived from the `source` values actually present in the file, so
/// adding a source to a category cannot leave the old credit line behind. Order
/// is fixed rather than alphabetical, so a refresh produces no spurious diff.
let attributionOrder: [(source: String, credit: String)] = [
    ("UT.no/DNT", "UT.no/DNT"),
    ("UT.no", "UT.no (data fra Statskog, fjellstyrer, kommuner, private m.fl.)"),
    ("Oslo kommune (Bymiljøetaten)", "Oslo kommune (Bymiljøetaten/NLOD)"),
    ("Wikidata", "Wikidata (CC0)"),
    ("OpenStreetMap", "OpenStreetMap contributors (ODbL)"),
]

func attribution(for features: [[String: Any]], fallback: String) -> String {
    // A feature without `source` is OSM — same assumption `fetch_osm_poi.swift`
    // makes, and the reason those files can lose their OSM credit if this
    // defaults to nothing.
    let sources = Set(features.map {
        ($0["properties"] as? [String: Any])?["source"] as? String ?? "OpenStreetMap"
    })
    // "UT.no/DNT" also has the "UT.no" prefix — match the longest label first so
    // a DNT-only file is not credited to Statskog as well.
    var credits: [String] = []
    var claimed = Set<String>()
    for entry in attributionOrder where sources.contains(entry.source) && !claimed.contains(entry.source) {
        credits.append(entry.credit)
        claimed.insert(entry.source)
    }
    return credits.isEmpty ? fallback : credits.joined(separator: ", ")
}

// MARK: - POI targets

let timestamp = ISO8601DateFormatter().string(from: Date())
var byType: [String: [[String: Any]]] = [:]
var droppedAttractions = 0
for node in poiNodes {
    guard (node["status"] as? String) == "PUBLIC" else { continue }
    guard let type = effectiveType(of: node) else {
        droppedAttractions += 1
        continue
    }
    byType[type, default: []].append(node)
}
if droppedAttractions > 0 {
    print("\(droppedAttractions) severdigheter droppet som bymål uten turverdi")
}

// Flere typer kan skrive til samme fil – utsiktspunkter får både «lookout point»
// og «mountain peak». De må behandles i samme omgang: `readExisting` regner alt
// med kilde UT.no som noe som skal erstattes, så to runder mot samme fil ville
// latt den andre slette det den første la inn.
var targetsByFile: [String: [Target]] = [:]
for target in targets { targetsByFile[target.outputFile, default: []].append(target) }

print("\nSlår sammen POI-er:")
for (outputFile, fileTargets) in targetsByFile.sorted(by: { $0.key < $1.key }) {
    let placeholder = fileTargets.compactMap(\.osmPlaceholder).first
    let (kept, previous) = readExisting(outputFile, idPrefix: fileTargets[0].idPrefix)

    var features: [[String: Any]] = []
    var current = Set<String>()

    for target in fileTargets {
    let nodes = byType[target.poiType] ?? []
    for node in nodes {
        guard let id = node["id"] as? Int, let point = coordinates(from: node) else { continue }

        var properties: [String: Any] = [
            "name": (node["name"] as? String) ?? "Sted",
            "source": "UT.no/DNT",
        ]
        if let html = node["description"] as? String,
           let text = plainText(html, leadOnly: false) {
            properties["description"] = text
        }
        if let elevation = point.elevation { properties["elevation"] = elevation }

        let featureId = "\(target.idPrefix)\(id)"
        current.insert(featureId)
        features.append([
            "type": "Feature",
            "id": featureId,
            "geometry": [
                "type": "Point",
                "coordinates": [round6(point.lon), round6(point.lat)],
            ] as [String: Any],
            "properties": properties,
        ])
    }
    }

    // Dedupliseringen ser hele settet, ikke bare de nye postene: den rydder
    // også dubletter internt i OSM-delen, og resultatet er uavhengig av
    // rekkefølgen postene kom inn i.
    let (merged, dropped) = deduplicate(kept + features, placeholder: placeholder)
    let credit = attribution(for: merged, fallback: "UT.no/DNT, OpenStreetMap contributors (ODbL)")
    guard let size = write(merged, to: outputFile, attribution: credit, timestamp: timestamp) else {
        exit(1)
    }

    let utKept = merged.filter { source(of: $0).hasPrefix("UT.no") }.count
    let added = current.subtracting(previous).count
    let removed = previous.subtracting(current).count
    print("  \(outputFile): \(merged.count) totalt "
          + "(\(utKept) fra UT.no, \(merged.count - utKept) fra andre kilder)")
    print("      UT-endring: +\(added) nye, -\(removed) borte")
    if !dropped.isEmpty {
        let utLosers = dropped.filter { $0.loser.contains("-ut-") }.count
        print("      \(dropped.count) dubletter fjernet "
              + "(\(utLosers) fra UT.no, \(dropped.count - utLosers) fra andre kilder)")
    }
    print("      \(String(format: "%.1f", Double(size) / 1024.0)) KB")
}

// MARK: - Cabins

print("\nSlår sammen hytter:")
for target in cabinTargets {
    let (kept, previous) = readExisting(target.outputFile, idPrefix: target.idPrefix)
    var features: [[String: Any]] = []
    var current = Set<String>()

    for node in cabinNodes {
        guard (node["status"] as? String) == "PUBLIC",
              (node["dntCabin"] as? Bool) == target.dntCabin,
              let id = node["id"] as? Int,
              let point = coordinates(from: node) else { continue }

        var properties: [String: Any] = [
            "name": (node["name"] as? String) ?? "Hytte",
            "source": target.source,
        ]
        if let level = node["serviceLevel"] as? String, let norwegian = serviceLevelNames[level] {
            properties["type"] = norwegian
        }
        if let html = node["description"] as? String,
           let text = plainText(html, leadOnly: true) {
            properties["description"] = text
        }
        if let elevation = point.elevation { properties["elevation"] = elevation }

        let beds = [
            node["bedsStaffed"] as? Int ?? 0,
            node["bedsSelfService"] as? Int ?? 0,
            node["bedsNoService"] as? Int ?? 0,
        ].max() ?? 0
        if beds > 0 { properties["beds"] = beds }

        if target.includeOwner,
           let group = node["ownerGroupConnection"] as? [String: Any],
           let owner = group["name"] as? String, !owner.isEmpty {
            properties["owner"] = owner
        }

        let featureId = "\(target.idPrefix)\(id)"
        current.insert(featureId)
        features.append([
            "type": "Feature",
            "id": featureId,
            "geometry": [
                "type": "Point",
                "coordinates": [round6(point.lon), round6(point.lat)],
            ] as [String: Any],
            "properties": properties,
        ])
    }

    let merged = kept + features
    let credit = attribution(for: merged, fallback: target.attribution)
    guard let size = write(merged, to: target.outputFile, attribution: credit, timestamp: timestamp) else {
        exit(1)
    }

    let added = current.subtracting(previous).count
    let removed = previous.subtracting(current).count
    print("  \(target.outputFile): \(features.count) hytter (+\(added) nye, -\(removed) borte), "
          + "\(String(format: "%.1f", Double(size) / 1024.0)) KB")
}

print("\nFerdig.")
