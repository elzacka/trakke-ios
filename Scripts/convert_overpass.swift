#!/usr/bin/env swift
//
// convert_overpass.swift
// Converts raw Overpass API JSON to clean GeoJSON FeatureCollections.
// Handles both node and way elements (ways get centroid coordinates).
//
// Usage: swift convert_overpass.swift
// Run from the Scripts/ directory. Reads *_raw.json, writes to ../Trakke/Resources/POIData/*.geojson

import Foundation

// MARK: - Overpass JSON types

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

struct OverpassElement: Decodable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let nodes: [Int]?
    let tags: [String: String]?
}

// MARK: - GeoJSON output types

struct GeoJSONFeatureCollection: Encodable {
    let type = "FeatureCollection"
    let generator = "Trakke convert_overpass.swift"
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

// MARK: - Conversion

struct CategoryConfig {
    let inputFile: String
    let outputFile: String
    let idPrefix: String
    let defaultName: String
    let propertyExtractor: ([String: String]) -> [String: String]
}

let categories: [CategoryConfig] = [
    CategoryConfig(
        inputFile: "caves_raw.json",
        outputFile: "caves.geojson",
        idPrefix: "cave",
        defaultName: "Hule",
        propertyExtractor: { tags in
            var props: [String: String] = [:]
            if let name = tags["name"] { props["name"] = name }
            if let desc = tags["description"] { props["description"] = desc }
            return props
        }
    ),
    CategoryConfig(
        inputFile: "towers_raw.json",
        outputFile: "observation_towers.geojson",
        idPrefix: "tower",
        defaultName: "Utsiktstårn",
        propertyExtractor: { tags in
            var props: [String: String] = [:]
            if let name = tags["name"] { props["name"] = name }
            if let height = tags["height"] { props["height"] = height }
            if let op = tags["operator"] { props["operator"] = op }
            // Determine subtype for display
            if tags["leisure"] == "bird_hide" {
                props["subtype"] = "bird_hide"
                if props["name"] == nil { props["name"] = "Fugletårn" }
            } else if tags["tower:type"] == "watchtower" {
                props["subtype"] = "watchtower"
                if props["name"] == nil { props["name"] = "Vakttårn" }
            }
            return props
        }
    ),
    CategoryConfig(
        inputFile: "war_raw.json",
        outputFile: "war_memorials.geojson",
        idPrefix: "memorial",
        defaultName: "Krigsminne",
        propertyExtractor: { tags in
            var props: [String: String] = [:]
            if let name = tags["name"] { props["name"] = name }
            if let inscription = tags["inscription"] { props["inscription"] = inscription }
            if let period = tags["memorial:period"] { props["period"] = period }
            // Include the specific type for display
            if tags["historic"] == "fort" { props["type"] = "fort" }
            else if tags["military"] == "bunker" || tags["historic"] == "bunker" { props["type"] = "bunker" }
            else if tags["historic"] == "battlefield" { props["type"] = "battlefield" }
            return props
        }
    ),
    CategoryConfig(
        inputFile: "shelters_raw.json",
        outputFile: "wilderness_shelters.geojson",
        idPrefix: "wilderness-shelter",
        defaultName: "Gapahuk",
        propertyExtractor: { tags in
            var props: [String: String] = [:]
            if let name = tags["name"] { props["name"] = name }
            if let shelterType = tags["shelter_type"] { props["shelterType"] = shelterType }
            if let desc = tags["description"] { props["description"] = desc }
            return props
        }
    ),
]

let scriptDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Trakke/Resources/POIData")

let timestamp = ISO8601DateFormatter().string(from: Date())

for config in categories {
    let inputPath = scriptDir.appendingPathComponent(config.inputFile)

    guard FileManager.default.fileExists(atPath: inputPath.path) else {
        print("Skipping \(config.inputFile): file not found")
        continue
    }

    guard let data = try? Data(contentsOf: inputPath) else {
        print("Error reading \(config.inputFile)")
        continue
    }

    guard let response = try? JSONDecoder().decode(OverpassResponse.self, from: data) else {
        print("Error decoding \(config.inputFile)")
        continue
    }

    // Build node coordinate lookup for way centroid calculation
    var nodeMap: [Int: (lat: Double, lon: Double)] = [:]
    for element in response.elements where element.type == "node" {
        if let lat = element.lat, let lon = element.lon {
            nodeMap[element.id] = (lat, lon)
        }
    }

    var seen = Set<Int>()
    var features: [GeoJSONFeature] = []

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
            let coords = nodes.compactMap { nodeMap[$0] }
            guard !coords.isEmpty else { continue }
            lat = coords.map(\.lat).reduce(0, +) / Double(coords.count)
            lon = coords.map(\.lon).reduce(0, +) / Double(coords.count)
        }

        guard let finalLat = lat, let finalLon = lon else { continue }

        let tags = element.tags ?? [:]
        var properties = config.propertyExtractor(tags)
        if properties["name"] == nil {
            properties["name"] = config.defaultName
        }

        let feature = GeoJSONFeature(
            id: "\(config.idPrefix)-\(element.id)",
            geometry: GeoJSONGeometry(coordinates: [finalLon, finalLat]),
            properties: properties
        )
        features.append(feature)
    }

    let collection = GeoJSONFeatureCollection(
        timestamp: timestamp,
        features: features
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    guard let output = try? encoder.encode(collection) else {
        print("Error encoding \(config.outputFile)")
        continue
    }

    let outputPath = outputDir.appendingPathComponent(config.outputFile)
    do {
        try output.write(to: outputPath)
        let sizeKB = Double(output.count) / 1024.0
        print("\(config.outputFile): \(features.count) features, \(String(format: "%.1f", sizeKB)) KB")
    } catch {
        print("Error writing \(config.outputFile): \(error)")
    }
}

print("\nDone. Timestamp: \(timestamp)")
