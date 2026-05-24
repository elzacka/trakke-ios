import SwiftUI

extension Color {
    /// Hex initializer for convenience
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    // MARK: - Trakke Design System

    enum Trakke {
        // MARK: Brand
        static let brand = Color(hex: "3e4533")
        static let brandDark = Color(hex: "2e3326")
        /// Mellom-grønn for handlingsknapper (action-bar-ikoner og
        /// fullbredde-knapper). Gir ~4.4:1 kontrast med hvit symbol/tekst
        /// (passer WCAG 1.4.11 for UI-komponenter).
        static let brandLight = Color(hex: "757d68")
        static let brandTint = Color(hex: "e9ece6")

        // MARK: Neutrals
        static let background = Color(hex: "fafaf7")
        static let surface = Color(hex: "ffffff")

        // MARK: Text
        static let text = Color(hex: "1a1d1b")
        static let textSecondary = Color(hex: "4a4f47")
        static let textTertiary = Color(hex: "4e534a")
        static let textSoft = Color(hex: "7c8278")
        static let textInverse = Color(hex: "ffffff")

        // MARK: Borders (PWA-trofast)
        static let border = Color(hex: "e4e5e1")
        static let borderStrong = Color(hex: "c9ccc5")

        // MARK: Toggle (custom — varm dempet salviegrønn for av-tilstand)
        static let toggleTrackOff = Color(hex: "cdd2c7")

        // MARK: Functional
        static let red = Color(hex: "c23a34")
        static let green = Color(hex: "2e9e5b")
        static let yellow = Color(hex: "8a6c00")

        // MARK: Semantic
        static let warning = Color(hex: "b45309")
        static let measurement = Color(hex: "d97706")

        // MARK: POI Categories
        static let poiShelter = Color(hex: "b58900")
        static let poiCave = Color(hex: "8b4513")
        static let poiViewpoint = Color(hex: "4a7c8a")
        static let poiWarMemorial = Color(hex: "7b4a6b")
        static let poiWildernessShelter = Color(hex: "b45309")
        static let poiCulturalHeritage = Color(hex: "6b5b8a")
        static let poiSwimmingSpot = Color(hex: "147a8c")
        static let poiSwimmingSpotBeach = Color(hex: "5fa8c4")

        // MARK: Map data palette
        // Distinct from brand: map-data colours need maximum contrast against
        // Kartverket topo (which is itself green + red + blue + beige). Brand
        // green stays for UI chrome.
        //
        // Routes + waypoints: deep saturated teal. Reads as a clear outdoor
        // marker without competing with brand-green for UI authority, and
        // stays distinct from Kartverket's pastel water/building blues thanks
        // to high chroma + white casing.
        // Activities: cobalt — kept distinct from routes so a recorded track
        // and a planned route never blur together on the same map.
        // Casing: 1.5pt white each side under a 4pt coloured stroke.
        static let mapRoute = Color(hex: "0F766E")
        static let mapActivity = Color(hex: "2255AA")
        static let mapWaypoint = Color(hex: "0F766E")
        static let mapHalo = Color(hex: "FFFFFF")

        // MARK: Route Palette (user-overridable per route)
        // Default route colour is mapRoute (#E07000) so first-time users always
        // get a route that pops on the topo. Additional palette entries allow
        // visual differentiation when several routes overlap.
        static let routeColors: [String] = [
            "#E07000", "#C4501A", "#7B3FC4", "#2255AA",
            "#1abc9c", "#9b59b6", "#e74c3c", "#795548",
        ]

        /// Norwegian color names for VoiceOver, matching routeColors order
        static let routeColorNames: [String] = [
            "oransje", "rustrød", "lilla", "blå",
            "turkis", "fiolett", "rød", "brun",
        ]
    }
}

// MARK: - UIColor Bridge

extension UIColor {
    enum Trakke {
        static let brand = UIColor(red: 0x3E / 255.0, green: 0x45 / 255.0, blue: 0x33 / 255.0, alpha: 1)
        static let warning = UIColor(hex: "b45309")
        static let measurement = UIColor(hex: "d97706")

        // Map data palette — see Color.Trakke.* counterparts.
        static let mapRoute = UIColor(hex: "0F766E")
        static let mapActivity = UIColor(hex: "2255AA")
        static let mapWaypoint = UIColor(hex: "0F766E")
        static let mapHalo = UIColor.white

        // POI Categories
        static let poiShelter = UIColor(hex: "b58900")
        static let poiCave = UIColor(hex: "8b4513")
        static let poiViewpoint = UIColor(hex: "4a7c8a")
        static let poiWarMemorial = UIColor(hex: "7b4a6b")
        static let poiWildernessShelter = UIColor(hex: "b45309")
        static let poiCulturalHeritage = UIColor(hex: "6b5b8a")
        static let poiSwimmingSpot = UIColor(hex: "147a8c")
        static let poiSwimmingSpotBeach = UIColor(hex: "5fa8c4")
    }

    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - Shadow Tokens

extension View {
    func trakkeCardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    func trakkeControlShadow() -> some View {
        shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    func trakkeFABShadow() -> some View {
        shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
    }
}
