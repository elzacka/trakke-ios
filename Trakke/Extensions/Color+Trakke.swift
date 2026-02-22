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
        static let brandTint = Color(hex: "e9ece6")

        // MARK: Neutrals
        static let background = Color(hex: "fafaf7")
        static let surface = Color(hex: "ffffff")

        // MARK: Text
        static let text = Color(hex: "1a1d1b")
        static let textSecondary = Color(hex: "4a4f47")
        static let textTertiary = Color(hex: "4e534a")
        static let textInverse = Color(hex: "ffffff")

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

        // MARK: Route Palette
        static let routeColors: [String] = [
            "#3e4533", "#e74c3c", "#795548", "#2ecc71",
            "#f39c12", "#9b59b6", "#1abc9c", "#e67e22",
        ]
    }
}

// MARK: - UIColor Bridge

extension UIColor {
    enum Trakke {
        static let brand = UIColor(red: 0x3E / 255.0, green: 0x45 / 255.0, blue: 0x33 / 255.0, alpha: 1)
        static let warning = UIColor(hex: "b45309")
        static let measurement = UIColor(hex: "d97706")

        // POI Categories
        static let poiShelter = UIColor(hex: "b58900")
        static let poiCave = UIColor(hex: "8b4513")
        static let poiViewpoint = UIColor(hex: "4a7c8a")
        static let poiWarMemorial = UIColor(hex: "7b4a6b")
        static let poiWildernessShelter = UIColor(hex: "b45309")
        static let poiCulturalHeritage = UIColor(hex: "6b5b8a")
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
