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
        static let dividerLeading: CGFloat = 4

        // Touch targets (WCAG)
        static let touchMin: CGFloat = 44
        static let touchComfortable: CGFloat = 48
    }

    enum TrakkeRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
}
