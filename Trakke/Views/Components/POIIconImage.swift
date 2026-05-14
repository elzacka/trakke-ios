import SwiftUI

/// Rendrer et POI-ikon — bruker asset-katalogen først, faller tilbake
/// til SF Symbol når asset ikke finnes. Lar nye POI-kategorier bruke
/// SF Symbol-navn uten å kreve en custom SVG i Assets.xcassets/.
struct POIIconImage: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size * 0.9))
                .frame(width: size, height: size)
        }
    }
}
