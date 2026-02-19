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

    // MARK: - Tråkke Design System

    enum Trakke {
        // MARK: Brand
        static let brand = Color(hex: "3e4533")
        static let brandSoft = Color(hex: "606756")
        static let brandTint = Color(hex: "e9ece6")

        // MARK: Neutrals
        static let background = Color(hex: "fafaf7")
        static let surface = Color(hex: "ffffff")
        static let surfaceSubtle = Color(hex: "f2f3f0")
        static let border = Color(hex: "e4e5e1")
        static let borderStrong = Color(hex: "c9ccc5")

        // MARK: Text
        static let text = Color(hex: "1a1d1b")
        static let textMuted = Color(hex: "4a4f47")
        static let textSoft = Color(hex: "7c8278")
        static let textInverse = Color(hex: "ffffff")

        // MARK: Functional
        static let blue = Color(hex: "1e6ce0")
        static let red = Color(hex: "d0443e")
        static let green = Color(hex: "2e9e5b")
        static let yellow = Color(hex: "d4a012")

        // MARK: POI Categories
        static let poiShelter = Color(hex: "fbbf24")
        static let poiCave = Color(hex: "8b4513")
        static let poiTower = Color(hex: "4a5568")
        static let poiWarMemorial = Color(hex: "6b7280")
        static let poiWildernessShelter = Color(hex: "b45309")
        static let poiCulturalHeritage = Color(hex: "8b7355")

        // MARK: Future POI (configured but not yet active in PWA)
        static let poiParking = Color(hex: "60a5fa")
        static let poiAlpineHut = Color(hex: "f59e0b")
        static let poiViewpoint = Color(hex: "10b981")
        static let poiMemorial = Color(hex: "6b7280")
    }
}

// MARK: - UIColor Bridge

extension UIColor {
    enum Trakke {
        static let brand = UIColor(red: 0x3E / 255.0, green: 0x45 / 255.0, blue: 0x33 / 255.0, alpha: 1)
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
