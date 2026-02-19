import SwiftUI

extension Font {
    enum Trakke {
        /// Brand headline font — Exo 2 Light (weight 300), scales with Dynamic Type
        static func brand(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
            .custom("Exo 2", size: size, relativeTo: textStyle).weight(.light)
        }

        /// Brand title — matches PWA header: 24pt light, scales with .title
        static var title: Font {
            brand(size: 24, relativeTo: .title)
        }

        /// Brand tagline — matches PWA: 12pt light, scales with .caption
        static var tagline: Font {
            brand(size: 12, relativeTo: .caption)
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
