#!/usr/bin/env swift
//
// fetch_dsb_shelters.swift
// Fetches all public emergency shelters (offentlige tilfluktsrom) and outputs GeoJSON.
//
// Primary source is Geonorge's WFS 2.0.0 service, which is the distribution
// Geonorge lists for DSB's dataset "Tilfluktsrom - Offentlige". It carries a
// stable UUID per shelter (app:lokalId) and a daily extraction timestamp,
// neither of which DSB's own mapserver at ogc.dsb.no exposes.
//
// DSB's mapserver is still queried as a secondary source, because the two are
// not always in sync: in August 2026 it listed romnr 15257 (Dr. Jensens veg 4)
// which the Geonorge extract did not. Losing coverage in an emergency-
// preparedness category is worse than carrying one record without a UUID, so
// shelters found only at DSB are merged in and reported.
//
// The attribute t_kategori (construction standard: "76-Rom A", "66-Rom" ...) was
// dropped from DSB's service between April and August 2026 and is absent from
// Geonorge as well. It is not written any more.
//
// Usage: swift fetch_dsb_shelters.swift
// Run from the Scripts/ directory. Writes ../Trakke/Resources/POIData/shelters.geojson

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - GeoJSON output

struct GeoJSONFeatureCollection: Encodable {
    let type = "FeatureCollection"
    let generator = "Trakke fetch_dsb_shelters.swift"
    let source = "DSB (Direktoratet for samfunnssikkerhet og beredskap) via Geonorge"
    let license = "NLOD 2.0"
    let timestamp: String
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Encodable {
    let type = "Feature"
    let id: String
    let geometry: GeoJSONGeometry
    let properties: [String: String]
}

struct GeoJSONGeometry: Encodable {
    let type = "Point"
    let coordinates: [Double] // [lon, lat]
}

// MARK: - Shelter record

struct Shelter {
    let localId: String?   // stable UUID, Geonorge only
    let romnr: String
    let plasser: String?
    let adresse: String?
    let lat: Double
    let lon: Double

    /// Stable across runs. Prefers the UUID; falls back to romnr for
    /// DSB-only records so the id does not change if the UUID shows up later.
    var featureId: String {
        if let localId, !localId.isEmpty { return "shelter-\(localId)" }
        return "shelter-romnr-\(romnr)"
    }

    var feature: GeoJSONFeature {
        var props: [String: String] = ["name": "Tilfluktsrom \(romnr)"]
        if let adresse, !adresse.isEmpty { props["address"] = adresse }
        if let plasser, !plasser.isEmpty { props["capacity"] = plasser }
        return GeoJSONFeature(
            id: featureId,
            geometry: GeoJSONGeometry(coordinates: [lon, lat]),
            properties: props
        )
    }
}

// MARK: - GML parser

/// Handles both services. The element local names are identical (romnr,
/// plasser, adresse, pos); Geonorge adds lokalId and wraps features in
/// wfs:member instead of gml:featureMember.
final class ShelterGMLParser: NSObject, XMLParserDelegate {
    var shelters: [Shelter] = []

    private var currentText = ""
    private var inFeature = false
    private var localId: String?
    private var romnr: String?
    private var adresse: String?
    private var plasser: String?
    private var position: String?

    private static let featureElements: Set<String> = ["featureMember", "member"]

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        currentText = ""

        if Self.featureElements.contains(name) {
            inFeature = true
            localId = nil
            romnr = nil
            adresse = nil
            plasser = nil
            position = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inFeature {
            switch name {
            case "lokalId": localId = text
            case "romnr": romnr = text
            case "adresse": adresse = text
            case "plasser": plasser = text
            case "pos": position = text
            default: break
            }
        }

        guard Self.featureElements.contains(name) else { return }
        inFeature = false

        // Both services deliver EPSG:4326 as "lat lon".
        guard let position, let romnr, !romnr.isEmpty else { return }
        let parts = position.split(separator: " ")
        guard parts.count >= 2,
              let lat = Double(parts[0]), let lon = Double(parts[1]),
              lat.isFinite, lon.isFinite,
              (-90...90).contains(lat), (-180...180).contains(lon) else { return }

        shelters.append(Shelter(
            localId: localId,
            romnr: romnr,
            plasser: plasser,
            adresse: adresse,
            lat: lat,
            lon: lon
        ))
    }
}

// MARK: - Fetching

func fetch(_ url: URL, label: String) -> Data? {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Data?
    var failure: Error?

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        result = data
        failure = error
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("\(label): HTTP \(http.statusCode)")
            result = nil
        }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()

    if let failure {
        print("\(label): \(failure.localizedDescription)")
        return nil
    }
    return result
}

func parseShelters(_ data: Data) -> [Shelter] {
    let delegate = ShelterGMLParser()
    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    parser.delegate = delegate
    parser.parse()
    return delegate.shelters
}

let geonorgeURL = URL(string: """
    https://wfs.geonorge.no/skwms1/wfs.tilfluktsrom_offentlige\
    ?service=WFS&version=2.0.0&request=GetFeature\
    &typenames=app:Tilfluktsrom&srsName=urn:ogc:def:crs:EPSG::4326
    """)!

var dsbComponents = URLComponents(string: "https://ogc.dsb.no/wfs.ashx")!
dsbComponents.queryItems = [
    URLQueryItem(name: "SERVICE", value: "WFS"),
    URLQueryItem(name: "VERSION", value: "1.1.0"),
    URLQueryItem(name: "REQUEST", value: "GetFeature"),
    URLQueryItem(name: "TYPENAME", value: "layer_340"),
    URLQueryItem(name: "SRSNAME", value: "EPSG:4326"),
]

print("Henter tilfluktsrom fra Geonorge WFS ...")
guard let geonorgeData = fetch(geonorgeURL, label: "Geonorge") else {
    print("Geonorge-tjenesten svarte ikke. Avbryter uten å skrive fil.")
    exit(1)
}
let geonorgeShelters = parseShelters(geonorgeData)
print("  \(geonorgeShelters.count) rom, \(geonorgeData.count / 1024) KB")

guard !geonorgeShelters.isEmpty else {
    print("Ingen rom parset fra Geonorge. Avbryter uten å skrive fil.")
    exit(1)
}

print("Henter tilfluktsrom fra DSB WFS (sekundærkilde) ...")
let dsbShelters = fetch(dsbComponents.url!, label: "DSB").map(parseShelters) ?? []
print("  \(dsbShelters.count) rom")

// Geonorge wins on every shared romnr; DSB only contributes what is missing.
var byRomnr: [String: Shelter] = [:]
for shelter in geonorgeShelters { byRomnr[shelter.romnr] = shelter }

var dsbOnly: [String] = []
for shelter in dsbShelters where byRomnr[shelter.romnr] == nil {
    byRomnr[shelter.romnr] = shelter
    dsbOnly.append(shelter.romnr)
}
if !dsbOnly.isEmpty {
    print("  Bare hos DSB, tatt med uten UUID: \(dsbOnly.sorted().joined(separator: ", "))")
}

// MARK: - Compare with the file on disk

let scriptDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Trakke/Resources/POIData")
let outputPath = outputDir.appendingPathComponent("shelters.geojson")

if let existing = try? Data(contentsOf: outputPath),
   let json = try? JSONSerialization.jsonObject(with: existing) as? [String: Any],
   let features = json["features"] as? [[String: Any]] {
    // The previous id scheme was shelter-<romnr>; the current one is
    // shelter-<uuid>. Compare on romnr, which survives both.
    let previous = Set(features.compactMap { feature -> String? in
        guard let props = feature["properties"] as? [String: Any],
              let name = props["name"] as? String else { return nil }
        return name.replacingOccurrences(of: "Tilfluktsrom ", with: "")
    })
    let current = Set(byRomnr.keys)
    let added = current.subtracting(previous).sorted()
    let removed = previous.subtracting(current).sorted()
    print("Mot forrige fil: \(previous.count) rom -> \(current.count) rom")
    if !added.isEmpty { print("  Nye: \(added.joined(separator: ", "))") }
    if !removed.isEmpty { print("  Borte: \(removed.joined(separator: ", "))") }
    if added.isEmpty && removed.isEmpty { print("  Ingen rom lagt til eller fjernet") }
}

// MARK: - Write

let features = byRomnr.values
    .map(\.feature)
    .sorted { $0.id < $1.id }

let collection = GeoJSONFeatureCollection(
    timestamp: ISO8601DateFormatter().string(from: Date()),
    features: features
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

guard let output = try? encoder.encode(collection) else {
    print("Klarte ikke å kode GeoJSON")
    exit(1)
}

do {
    try output.write(to: outputPath)
    let sizeKB = Double(output.count) / 1024.0
    print("shelters.geojson: \(features.count) rom, \(String(format: "%.1f", sizeKB)) KB")
} catch {
    print("Klarte ikke å skrive shelters.geojson: \(error)")
    exit(1)
}
