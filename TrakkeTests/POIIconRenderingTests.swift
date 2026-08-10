import Testing
import UIKit
@testable import Trakke

/// Et POI-ikon kan «finnes» og likevel tegne feil. To feil har skjedd:
/// et strekbasert SVG som ikke rendres i det hele tatt (tomt kartsymbol, ingen
/// feilmelding), og et SVG med hvite bakgrunnsrektangler som i template-modus
/// ble fylt med kategorifargen og ga en heldekkende firkant.
///
/// Testen rendrer hvert ikon og måler hvor stor del av flata som har farge.
/// Grensene er romslige – de skal fange «ingenting» og «alt», ikke smaken.
@Test("Alle POI-ikoner tegner en glyf, ikke tomt eller heldekkende",
      arguments: POICategory.allCases)
func poiCategoryIconDrawsGlyph(category: POICategory) throws {
    let name = category.iconName
    let image = try #require(
        UIImage(named: name) ?? UIImage(systemName: name),
        "Ikon «\(name)» for \(category.rawValue) finnes ikke"
    )

    let side = 64
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    format.scale = 1
    let rendered = UIGraphicsImageRenderer(
        size: CGSize(width: side, height: side), format: format
    ).image { _ in
        image.withRenderingMode(.alwaysTemplate)
            .withTintColor(.black, renderingMode: .alwaysTemplate)
            .draw(in: CGRect(x: 0, y: 0, width: side, height: side))
    }

    let cgImage = try #require(rendered.cgImage, "\(name) ga ingen bitmap")
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    let context = CGContext(
        data: &pixels, width: side, height: side, bitsPerComponent: 8,
        bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

    let inked = stride(from: 3, to: pixels.count, by: 4)
        .reduce(0) { $0 + (pixels[$1] > 20 ? 1 : 0) }
    let coverage = Double(inked) / Double(side * side)

    #expect(coverage > 0.03, "«\(name)» tegner nesten ingenting (\(Int(coverage * 100)) %)")
    #expect(coverage < 0.90, "«\(name)» dekker nesten hele flata (\(Int(coverage * 100)) %) – bakgrunnsrektangel?")
}
