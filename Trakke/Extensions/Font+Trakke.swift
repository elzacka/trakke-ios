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
        static var articleHeading: Font { .subheadline.weight(.semibold) }
        static var bodyMedium: Font { .subheadline.weight(.medium) }
        static var bodyRegular: Font { .subheadline }
        static var caption: Font { .caption }
        static var captionSoft: Font { .caption2 }

        // Tooltip body — larger than caption for readable explanations outdoors
        static var tooltipBody: Font { .footnote }

        // Section headers (CardSection)
        static var sectionHeader: Font { .caption }

        // Numeral styles (for distance/area readouts, compass distance)
        static var numeralLarge: Font { .title3.monospacedDigit().bold() }
        static var numeralXLarge: Font { .title2.monospacedDigit().bold() }

        // Temperature display (weather)
        static var temperature: Font { .system(.largeTitle, design: .rounded, weight: .light) }

        // Morse code display (SOS signal) — monospaced for even character spacing
        static var morse: Font { .system(.title, design: .monospaced, weight: .bold) }

        // Compass arrow — sized via @ScaledMetric, uses system font
        static var compassArrow: Font { .system(.title) }
    }
}
