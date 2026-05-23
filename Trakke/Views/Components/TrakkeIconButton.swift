import SwiftUI

/// Standardisert ikon-knapp for sekundære handlinger inline i list-ark
/// (importer, eksporter, slett). 44×44 tap-areal med samme `surface`-flate
/// og rounded-rectangle-radius som CardSection — sitter naturlig inn i
/// list-ark-layouten uten å fremstå som flytende kontroll. Brukes typisk
/// i en høyrejustert HStack med flere ikoner som "sekundær-toolbar"
/// nederst i listen.
///
/// VoiceOver: `accessibilityLabel` må alltid settes siden visningen er
/// rent ikonisk. Når `isLoading` er true vises en spinner i stedet for
/// ikonet, og knappen er disabled. Tap-arealet er konstant — ingen
/// layout-skift når tilstand endres.
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
                        .tint(color)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(color)
                }
            }
            .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
            .background(Color.Trakke.surface)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
    }

    private var color: Color {
        switch role {
        case .neutral: Color.Trakke.brand
        case .destructive: Color.Trakke.red
        }
    }
}
