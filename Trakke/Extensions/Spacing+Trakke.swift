import SwiftUI

// MARK: - Spacing Guide
//
// Bruk regler – først semantiske tokens, så atomiske som fallback.
//
// SEMANTISKE (foretrukket – beskriver formål):
//   sheetHorizontal  Horisontal innrykk inni en sheet/scrollview (20).
//   sheetTop         Topp-padding rett under drag-indicator (8).
//   cardPadH/V       Padding inni CardSection (16h / 12v).
//   cardGap          Avstand mellom kort i en VStack (24).
//   rowVertical      Vertikal padding i list-rader (6).
//   labelGap         Knapp/label-til-ikon-avstand (2).
//   dividerLeading   Indrag for Divider inni kort (4).
//   buttonPadV       Vertikal padding i TrakkeButtonStyle (14).
//   iconSlot/Large   Fast bredde for ikoner i rader (24 / 28).
//   badgePadH/V      Tett padding for pill-formet badge (6 / 2).
//
// ATOMISKE (bruk når intet semantisk token passer):
//   xs=4  sm=8  md=12  lg=16  xl=20  xxl=24
//   Holder seg til et 4 px-grid for visuell rytme.
//
// TOUCH TARGETS:
//   touchMin=44       WCAG-minimum for interaktive elementer.
//   touchComfortable=48  Komfortabel størrelse (foretrukket FAB/CTA).
//   touchCTA=72       Forhøyet for SOS/nød-knapper.
//
// Når du legger til nytt semantisk token: dokumenter formålet her.

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
        /// Emergency CTA button height – intentionally oversized for SOS actions
        static let touchCTA: CGFloat = 72

        /// Minimum bunn-padding for innhold inni AppMenuSheet – sikrer
        /// komfortabel klaring over den flytende BottomNavBar (52pt pille +
        /// 12pt margin + 24pt visuell luft = 88pt).
        static let bottomNavClearance: CGFloat = 88

        /// Høyde på den usynlige trykkflaten under innhold i søkeark, slik at
        /// et trykk i tomrommet også lukker skjermtastaturet.
        static let keyboardDismissArea: CGFloat = 240

        // Button padding – kompakt vertikalt for å unngå dominerende knapper
        static let buttonPadV: CGFloat = 10

        // Icon slots for list rows
        static let iconSlot: CGFloat = 24      // SF Symbol icons in navigation rows

        // Badge padding – intentionally tight for compact layout
        static let badgePadH: CGFloat = 6
        static let badgePadV: CGFloat = 2
    }

    /// Enhetlig hjørneskala – bruk den minste verdien som matcher rollen.
    ///
    /// - `sm` (6pt): Små badges, chips, scale bar.
    /// - `lg` (12pt): Innholdsflater – kort, knapper, søkefelt, listeelementer.
    /// - `xl` (16pt): Fremtredende flater – modaler/dialoger, store CTA-er,
    ///   store kart-knapper (FAB, kompass, vær-pille).
    /// - `sheet` (20pt): iOS sheet-presentasjon (system).
    ///
    /// Mellomverdien `md` (8pt) er fjernet – vi bruker bare disse fire trinnene
    /// for å holde uttrykket enhetlig.
    enum TrakkeRadius {
        static let sm: CGFloat = 6
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        /// Matches iOS 26 system default; set explicitly to prevent future regressions
        static let sheet: CGFloat = 20
    }
}
