#!/usr/bin/env swift
//
// generate_overlay_thumbnails.swift
// Generates the preview thumbnails for the map-layer picker (OverlayThumbnailGrid).
//
// One 480x320 PNG per OverlayLayer case, written as an .imageset under
// ../Trakke/Resources/Assets.xcassets/OverlayThumbs/ (single 3x entry, the
// LegendSymbols convention). Each thumbnail is a Kartverket topo base image
// with the overlay's own WMS/ArcGIS rendering composited on top at the SAME
// opacity the app uses — keep the opacity table below in sync with
// OverlayLayer.opacity in KartverketTileService.swift.
//
// Base map: https://wms.geonorge.no/skwms1/wms.topo (layer "topo", EPSG:3857) —
// GetCapabilities-verified 2026-08-09. Overlay endpoints match the app's
// OverlayLayer.tileURL, with two deliberate exceptions:
//  - bratthetskart: the app uses the WMTS XYZ cache; this script uses the
//    service's ArcGIS export endpoint (verified 2026-08-09) for an arbitrary bbox.
//  - svekketIs: the thumbnail uses only the _N1000 overview layers over a wide
//    bbox (the detail layers only draw at scale < 1:302 381, and weakened-ice
//    geometry is sparse — the overview over the Valdres/Randsfjorden reservoirs
//    is the reliably non-empty rendering, verified 2026-08-09).
//
// Every bbox below was chosen so the WMS actually draws content at 480 px:
// scale denominator = bboxWidth / (480 * 0.00028). Gates that matter:
// eiendomsgrense < 1:40 000 (bbox width must stay under ~5.37 km),
// innsjodybde layers < 1:151 191 and
// Dybdekontur < 1:200 000. Content-verified bboxes 2026-08-09 (GetMap byte
// size well above the ~1.4 KB fully-transparent baseline).
//
// Licenses: NVE (NLOD), Kartverket (CC BY 4.0 / open), Miljødirektoratet (NLOD).
//
// Usage: swift generate_overlay_thumbnails.swift [case ...]
// Run from the Scripts/ directory. No arguments = all 11 layers; otherwise a
// subset of OverlayLayer rawValues (e.g. "svekketIs kvikkleire").
// Fails loudly (exit 1) if a response is not a PNG, if an overlay renders
// (nearly) nothing, or if the base map comes back blank.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let width = 480
let height = 320

struct ThumbnailSpec {
    let rawValue: String
    /// EPSG:3857 "minX,minY,maxX,maxY", 3:2 aspect to match 480x320.
    let bbox: String
    /// Must equal OverlayLayer.opacity for the same case.
    let opacity: CGFloat
    /// Full overlay image URL for the bbox (WMS GetMap or ArcGIS export).
    let overlayURL: (String) -> String
}

func wmsGetMap(endpoint: String, layers: String, styles: String = "", bbox: String) -> String {
    "\(endpoint)?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
        + "&LAYERS=\(layers)&STYLES=\(styles)&SRS=EPSG:3857"
        + "&BBOX=\(bbox)&WIDTH=\(width)&HEIGHT=\(height)"
        + "&FORMAT=image/png&TRANSPARENT=true"
}

let specs: [ThumbnailSpec] = [
    // Nordmarka: trail-dense terrain.
    ThumbnailSpec(rawValue: "turrutebasen", bbox: "1180000,8395000,1195000,8405000", opacity: 0.7) {
        wmsGetMap(endpoint: "https://wms.geonorge.no/skwms1/wms.friluftsruter2",
                  layers: "Fotrute", styles: "default", bbox: $0)
    },
    // Jotunheimen nasjonalpark.
    ThumbnailSpec(rawValue: "naturvernomrader", bbox: "930000,8720000,975000,8750000", opacity: 0.5) {
        wmsGetMap(endpoint: "https://wms.miljodirektoratet.no/arcgis/services/vern/MapServer/WMSServer",
                  layers: "naturvern_omrade", bbox: $0)
    },
    // Trillemarka.
    ThumbnailSpec(rawValue: "naturskog", bbox: "1046000,8400000,1076000,8420000", opacity: 0.7) {
        "https://image001.miljodirektoratet.no/arcgis/rest/services/naturskog/naturskog_v1/MapServer/export"
            + "?bbox=\($0)&bboxSR=3857&imageSR=3857&size=\(width),\(height)"
            + "&format=png32&transparent=true&layers=show:1&f=image"
    },
    // Hemsedal: steep terrain. Export endpoint verified 2026-08-09.
    ThumbnailSpec(rawValue: "bratthetskart", bbox: "935000,8578000,965000,8598000", opacity: 0.9) {
        "https://gis3.nve.no/arcgis/rest/services/wmts/Bratthet_2024/MapServer/export"
            + "?bbox=\($0)&bboxSR=3857&imageSR=3857&size=\(width),\(height)"
            + "&format=png32&transparent=true&f=image"
    },
    // Nordmarka at ~1:45k — tight enough that the 1 km grid actually draws
    // (at coarser scales the service renders only the 10 km lines).
    ThumbnailSpec(rawValue: "utmRunenett", bbox: "1186000,8395000,1192000,8399000", opacity: 0.8) {
        wmsGetMap(endpoint: "https://wms.geonorge.no/skwms1/wms.rutenett",
                  layers: "10km_rutelinje,1km_rutelinje", bbox: $0)
    },
    // Valdres/Randsfjorden reservoirs, overview (_N1000) layers only — see header.
    ThumbnailSpec(rawValue: "svekketIs", bbox: "1090000,8560000,1157200,8604800", opacity: 0.8) {
        wmsGetMap(endpoint: "https://kart.nve.no/enterprise/services/SvekketIs1/MapServer/WMSServer",
                  layers: "SvekketIs_N1000,OppsprukketIsLangsLand_N1000", bbox: $0)
    },
    // Tiller/Klæbu south of Trondheim: large, strongly graded zones.
    ThumbnailSpec(rawValue: "kvikkleire", bbox: "1150000,9186000,1165000,9196000", opacity: 0.6) {
        wmsGetMap(endpoint: "https://kart.nve.no/enterprise/services/SkredKvikkleire2/MapServer/WMSServer",
                  layers: "KvikkleireFaregrad", bbox: $0)
    },
    // Nordstrand, Oslo: dense residential parcels, all on land. Width 5.0 km
    // keeps the 480 px scale at ~1:37 200, under the service's 1:40 000 gate
    // (5.4 km would land at 1:40 178 and render empty).
    ThumbnailSpec(rawValue: "eiendomsgrenser", bbox: "1200000,8367000,1205000,8370333", opacity: 0.9) {
        wmsGetMap(endpoint: "https://wms.geonorge.no/skwms1/wms.matrikkelkart",
                  layers: "eiendomsgrense", bbox: $0)
    },
    // Skåtøy/Jomfruland, Kragerø coast (the Hvaler candidate rendered empty).
    ThumbnailSpec(rawValue: "ferdselsforbud", bbox: "1052000,8138000,1067000,8148000", opacity: 0.7) {
        wmsGetMap(endpoint: "https://wms.miljodirektoratet.no/arcgis/services/vern_restriksjonsomrader/MapServer/WMSServer",
                  layers: "ferdselsforbud", bbox: $0)
    },
    // Tinnsjå mid-lake (vatnlnr 2 in the Innsjødatabasen, depth-mapped —
    // located via the REST query layer 3 "Innsjo_ved_dybdemaling" 2026-08-09;
    // the Mjøsa/Randsfjorden candidates rendered empty). 18 km wide ≈ 1:134k,
    // under the layers' 1:151 191 gate.
    ThumbnailSpec(rawValue: "innsjodybde", bbox: "989087,8358457,1007087,8370457", opacity: 0.7) {
        wmsGetMap(endpoint: "https://kart.nve.no/enterprise/services/Innsjodatabase2/MapServer/WMSServer",
                  layers: "Innsjo_ved_dybdemaling,DybdeKurve", bbox: $0)
    },
    // Romsdalen: steep country with documented avalanche terrain, 6 km wide
    // (≈ 1:45k). The gate is 1:75 595, and it bites hard: the same centre at
    // 12 km wide (1:89k) renders completely empty. The S3 variant draws as a red
    // hatch, which is what the card needs to show.
    ThumbnailSpec(rawValue: "snoskredAktsomhet", bbox: "860433,8962535,866433,8966535", opacity: 0.8) {
        wmsGetMap(endpoint: "https://kart.nve.no/enterprise/services/SnoskredAktsomhet/MapServer/WMSServer",
                  layers: "S3_snoskred_Aktsomhetsomrade", bbox: $0)
    },
]

func baseMapURL(bbox: String) -> String {
    wmsGetMap(endpoint: "https://wms.geonorge.no/skwms1/wms.topo", layers: "topo", bbox: bbox)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("ERROR: " + message + "\n").utf8))
    exit(1)
}

func fetchPNG(_ urlString: String, label: String) -> CGImage {
    guard let url = URL(string: urlString) else { fail("\(label): invalid URL \(urlString)") }
    guard let data = try? Data(contentsOf: url) else { fail("\(label): request failed \(urlString)") }
    // ArcGIS reports errors as XML with HTTP 200 — the PNG signature is the
    // reliable check.
    let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    guard data.count > 8, [UInt8](data.prefix(4)) == pngSignature else {
        let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
        fail("\(label): response is not a PNG (\(data.count) bytes): \(preview)")
    }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("\(label): PNG could not be decoded")
    }
    return image
}

func rgbaPixels(of image: CGImage) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
        data: &pixels, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}

/// Fraction of pixels with any alpha — a fully transparent GetMap means the
/// bbox missed the data and the thumbnail would silently show plain base map.
func alphaCoverage(of image: CGImage) -> Double {
    let pixels = rgbaPixels(of: image)
    var covered = 0
    for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] > 0 {
        covered += 1
    }
    return Double(covered) / Double(width * height)
}

func isUniform(_ image: CGImage) -> Bool {
    let pixels = rgbaPixels(of: image)
    let first = Array(pixels.prefix(4))
    for i in stride(from: 0, to: pixels.count, by: 4) where Array(pixels[i..<i + 4]) != first {
        return false
    }
    return true
}

func composite(base: CGImage, overlay: CGImage, opacity: CGFloat) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    context.draw(base, in: rect)
    context.setAlpha(opacity)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.draw(overlay, in: rect)
    context.endTransparencyLayer()
    return context.makeImage()!
}

func writeImageset(_ image: CGImage, rawValue: String, into assetsDir: URL) throws {
    let name = "overlay-thumb-\(rawValue)"
    let imagesetDir = assetsDir.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: imagesetDir, withIntermediateDirectories: true)

    let pngURL = imagesetDir.appendingPathComponent("\(name).png")
    guard let destination = CGImageDestinationCreateWithURL(
        pngURL as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { fail("\(rawValue): could not create \(pngURL.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("\(rawValue): PNG write failed") }

    let contents = """
    {
      "images": [
        {
          "idiom": "universal",
          "scale": "1x"
        },
        {
          "idiom": "universal",
          "scale": "2x"
        },
        {
          "filename": "\(name).png",
          "idiom": "universal",
          "scale": "3x"
        }
      ],
      "info": {
        "author": "xcode",
        "version": 1
      }
    }
    """
    try (contents + "\n").write(
        to: imagesetDir.appendingPathComponent("Contents.json"),
        atomically: true, encoding: .utf8
    )
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let assetsDir = scriptDir
    .appendingPathComponent("../Trakke/Resources/Assets.xcassets/OverlayThumbs")
    .standardizedFileURL
try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

let groupContents = assetsDir.appendingPathComponent("Contents.json")
if !FileManager.default.fileExists(atPath: groupContents.path) {
    try """
    {
      "info": {
        "author": "xcode",
        "version": 1
      }
    }
    """.appending("\n").write(to: groupContents, atomically: true, encoding: .utf8)
}

let requested = Set(CommandLine.arguments.dropFirst())
if let unknown = requested.first(where: { name in !specs.contains { $0.rawValue == name } }) {
    fail("unknown layer \"\(unknown)\" — valid: \(specs.map(\.rawValue).joined(separator: " "))")
}
let selected = requested.isEmpty ? specs : specs.filter { requested.contains($0.rawValue) }

for spec in selected {
    print("[\(spec.rawValue)] base map…")
    let base = fetchPNG(baseMapURL(bbox: spec.bbox), label: "\(spec.rawValue) base")
    if isUniform(base) { fail("\(spec.rawValue): base map came back blank") }

    print("[\(spec.rawValue)] overlay…")
    let overlay = fetchPNG(spec.overlayURL(spec.bbox), label: "\(spec.rawValue) overlay")
    let coverage = alphaCoverage(of: overlay)
    if coverage < 0.005 {
        fail("\(spec.rawValue): overlay renders almost nothing "
            + "(\(String(format: "%.2f", coverage * 100)) % coverage) for bbox \(spec.bbox) "
            + "— pick a bbox that hits the data")
    }

    let thumb = composite(base: base, overlay: overlay, opacity: spec.opacity)
    try writeImageset(thumb, rawValue: spec.rawValue, into: assetsDir)
    print("[\(spec.rawValue)] OK (\(String(format: "%.1f", coverage * 100)) % overlay coverage)")
}

print("Done: \(selected.count) thumbnail(s) written to \(assetsDir.path)")
