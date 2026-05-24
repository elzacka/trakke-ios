import SwiftUI

/// Standardisert ikon-knapp for sekundære handlinger inline i list-ark
/// (importer, eksporter, slett, +). 44×44 tap-areal med brand-light
/// bakgrunn og hvit symbol — visuelt skille fra info-rader i samme kort.
///
/// VoiceOver: `accessibilityLabel` må alltid settes siden visningen er
/// rent ikonisk. Når `isLoading` er true vises en spinner i stedet for
/// ikonet, og knappen er disabled. Tap-arealet er konstant — ingen
/// layout-skift når tilstand endres.
///
/// `role: .destructive` gir samme visuelle stil som `.neutral` (brand-
/// light bg, hvit symbol) — bevisst valg slik at alle action-bar-knapper
/// ser likt ut. Bekreftelses-dialog beskytter slette-handlinger;
/// destructive-rollen beholdes for VoiceOver-semantikk.
struct TrakkeIconButton: View {
    enum Role { case neutral, destructive }

    let systemImage: String
    var role: Role = .neutral
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(iconColor)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(iconColor)
                }
            }
            .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Disabled-state har lys grønntint som bakgrunn (brandTint) og
    /// textSoft som ikon — ikonet forblir tydelig synlig (~3.7:1
    /// kontrast på brandTint, passer WCAG 1.4.11 for UI-komponenter)
    /// slik at brukeren ser hvilke handlinger som finnes selv før det
    /// er innhold å handle på.
    private var backgroundColor: Color {
        isEnabled ? Color.Trakke.brandLight : Color.Trakke.brandTint
    }

    private var iconColor: Color {
        isEnabled ? Color.Trakke.surface : Color.Trakke.textSoft
    }
}
