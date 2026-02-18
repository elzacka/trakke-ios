import SwiftUI

extension Font {
    enum Trakke {
        /// Brand headline font — Exo 2 Light (weight 300)
        static func brand(size: CGFloat) -> Font {
            .custom("Exo 2", size: size).weight(.light)
        }

        /// Brand title — matches PWA header: 24pt light
        static var title: Font {
            brand(size: 24)
        }

        /// Brand tagline — matches PWA: 12pt light
        static var tagline: Font {
            brand(size: 12)
        }

        // Body text styles
        static var bodyMedium: Font { .subheadline.weight(.medium) }
        static var bodyRegular: Font { .subheadline }
        static var caption: Font { .caption }
        static var captionSoft: Font { .caption2 }

        // Section headers (CardSection)
        static var sectionHeader: Font { .caption }
    }
}
