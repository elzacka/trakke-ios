import SwiftUI

extension CGFloat {
    enum Trakke {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24

        // Semantic
        static let sheetHorizontal: CGFloat = 20
        static let sheetTop: CGFloat = 8
        static let cardPadH: CGFloat = 16
        static let cardPadV: CGFloat = 12
        static let cardGap: CGFloat = 24
        static let rowVertical: CGFloat = 6
        static let labelGap: CGFloat = 2
        static let dividerLeading: CGFloat = 4

        // Touch targets (WCAG)
        static let touchMin: CGFloat = 44
        static let touchComfortable: CGFloat = 48
        /// Emergency CTA button height — intentionally oversized for SOS actions
        static let touchCTA: CGFloat = 72

        // Button padding — between md (12) and lg (16) for primary/secondary/danger buttons
        static let buttonPadV: CGFloat = 14

        // Icon slots for list rows
        static let iconSlot: CGFloat = 24      // SF Symbol icons in navigation rows
        static let iconSlotLarge: CGFloat = 28  // Weather symbols, search icons, POI outer frame

        // Badge padding — intentionally tight for compact layout
        static let badgePadH: CGFloat = 6
        static let badgePadV: CGFloat = 2
    }

    enum TrakkeRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        /// Matches iOS 26 system default; set explicitly to prevent future regressions
        static let sheet: CGFloat = 20
    }
}
