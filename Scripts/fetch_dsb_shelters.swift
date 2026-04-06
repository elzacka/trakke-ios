#!/usr/bin/env swift
//
// fetch_dsb_shelters.swift
// Fetches all emergency shelters (tilfluktsrom) from DSB WFS and outputs GeoJSON.
//
// Usage: swift fetch_dsb_shelters.swift
// Run from the Scripts/ directory. Writes to ../Trakke/Resources/POIData/shelters.geojson

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - GeoJSON output

struct GeoJSONFeatureCollection: Encodable {
    let type = "FeatureCollection"
    let generator = "Trakke fetch_dsb_shelters.swift"
    let source = "DSB (Direktoratet for samfunnssikkerhet og beredskap)"
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

// MARK: - GML Parser

class ShelterGMLParser: NSObject, XMLParserDelegate {
    var features: [GeoJSONFeature] = []

    private var currentElement = ""
    private var currentText = ""
    private var inFeature = false
    private var romnr: String?
    private var adresse: String?
    private var plasser: String?
    private var kategori: String?
    private var coordinates: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
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

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
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
                let parts = coordStr.split(separator: " ")
                if parts.count >= 2,
                   let lat = Double(parts[0]),
                   let lon = Double(parts[1]),
                   lat.isFinite, lon.isFinite {

                    let id = romnr ?? "\(lat)-\(lon)"
                    let displayName = "Tilfluktsrom \(romnr ?? "")".trimmingCharacters(in: .whitespaces)

                    var props: [String: String] = ["name": displayName]
                    if let addr = adresse, !addr.isEmpty { props["address"] = addr }
                    if let cap = plasser, !cap.isEmpty { props["capacity"] = cap }
                    if let kat = kategori, !kat.isEmpty { props["category"] = kat }

                    features.append(GeoJSONFeature(
                        id: "shelter-\(id)",
                        geometry: GeoJSONGeometry(coordinates: [lon, lat]),
                        properties: props
                    ))
                }
            }
        }
    }
}

// MARK: - Main

let scriptDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Trakke/Resources/POIData")

// Fetch all shelters from DSB WFS (no bbox = entire Norway)
var components = URLComponents(string: "https://ogc.dsb.no/wfs.ashx")!
components.queryItems = [
    URLQueryItem(name: "SERVICE", value: "WFS"),
    URLQueryItem(name: "VERSION", value: "1.1.0"),
    URLQueryItem(name: "REQUEST", value: "GetFeature"),
    URLQueryItem(name: "TYPENAME", value: "layer_340"),
    URLQueryItem(name: "SRSNAME", value: "EPSG:4326"),
]

let url = components.url!
print("Fetching shelters from DSB WFS...")

let semaphore = DispatchSemaphore(value: 0)
var responseData: Data?
var responseError: Error?

let task = URLSession.shared.dataTask(with: url) { data, response, error in
    responseData = data
    responseError = error
    semaphore.signal()
}
task.resume()
semaphore.wait()

guard let data = responseData else {
    print("Error fetching DSB data: \(responseError?.localizedDescription ?? "unknown")")
    exit(1)
}

print("Received \(data.count) bytes, parsing GML...")

let gmlParser = ShelterGMLParser()
let xmlParser = XMLParser(data: data)
xmlParser.shouldResolveExternalEntities = false
xmlParser.delegate = gmlParser
xmlParser.parse()

let timestamp = ISO8601DateFormatter().string(from: Date())
let collection = GeoJSONFeatureCollection(
    timestamp: timestamp,
    features: gmlParser.features
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

guard let output = try? encoder.encode(collection) else {
    print("Error encoding GeoJSON")
    exit(1)
}

let outputPath = outputDir.appendingPathComponent("shelters.geojson")
do {
    try output.write(to: outputPath)
    let sizeKB = Double(output.count) / 1024.0
    print("shelters.geojson: \(gmlParser.features.count) features, \(String(format: "%.1f", sizeKB)) KB")
} catch {
    print("Error writing shelters.geojson: \(error)")
    exit(1)
}

print("Done. Timestamp: \(timestamp)")
