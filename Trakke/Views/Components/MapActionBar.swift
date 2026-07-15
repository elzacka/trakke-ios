import SwiftUI

/// Felles pille-stil for karthandlinger — speiler Nav-HUD-pillen for at alle
/// modus-toolbars (Logg tur, Tegn rute, Måleverktøy, Offline-utvalg) føles
/// som varianter av samme komponent, ikke fire ulike paradigmer.
///
/// Bruk:
/// ```
/// MapActionBar {
///     MapActionStat(icon: "timer", value: duration)
///     MapActionDivider()
///     MapActionButton(systemImage: "xmark", role: .destructive, action: cancel)
/// }
/// ```
///
/// Plassering: Nav-HUD ligger på toppen (aktiv tilstand), verktøy-toolbars
/// nederst (tommelvennlig handling). Begge bruker samme pille-form, samme
/// surface, samme delere.
struct MapActionBar<Content: View>: View {
    enum VerticalPosition { case top, bottom }
    let position: VerticalPosition
    /// Ekstra forskyvning fra topp — brukes når flere pillerader skal stables
    /// (f.eks. opptak under nav-HUD). Ignoreres for `.bottom`.
    let topOffset: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        position: VerticalPosition = .bottom,
        topOffset: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.position = position
        self.topOffset = topOffset
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if position == .bottom { Spacer(minLength: 0) }

            HStack(spacing: 0) {
                content()
            }
            .background(Color.Trakke.surface.opacity(0.92))
            .clipShape(Capsule())
            .trakkeControlShadow()
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .padding(.top, position == .top ? topOffset : 0)

            if position == .top { Spacer(minLength: 0) }
        }
        .safeAreaPadding(position == .bottom ? .bottom : .top)
    }
}

/// Vertikal 1pt-deler — identisk med Nav-HUDs `navBarDivider`.
struct MapActionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.Trakke.border)
            .frame(width: 1, height: 24)
    }
}

/// Stat-celle med ikon + verdi. Brukes for tid, distanse, høyde osv.
struct MapActionStat: View {
    let icon: String
    let value: String
    var color: Color = Color.Trakke.text
    var accessibilityLabel: String?

    var body: some View {
        HStack(spacing: .Trakke.xs) {
            // Text-style fonts (not @ScaledMetric) so the .dynamicTypeSize cap
            // below actually bounds them — a same-view @ScaledMetric resolves
            // from the parent environment before the cap applies.
            Image(systemName: icon)
                .font(.system(.caption, weight: .regular))
                .foregroundStyle(Color.Trakke.textSoft)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, .Trakke.sm)
        .frame(maxWidth: .infinity, minHeight: 44)
        // HUD-pillen har begrenset bredde — cap veksten så distanse/fart-stats
        // ikke sprenger kapselen ved de største tilgjengelighetsstørrelsene.
        .dynamicTypeSize(...(.accessibility2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel ?? value)
    }
}

/// Tekst-celle for korte forklaringer (f.eks. "Trykk på kartet").
struct MapActionHint: View {
    let text: String

    @ScaledMetric(relativeTo: .caption) private var textSize: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.system(size: textSize, weight: .regular))
            .foregroundStyle(Color.Trakke.textSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, .Trakke.md)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// Ikon-knapp i pillen. `role` styrer farge (brand for nøytral, red for
/// destruktiv, recording for opptak-stopp).
struct MapActionButton: View {
    enum Role { case neutral, destructive, recording, primary }
    let systemImage: String
    var role: Role = .neutral
    var isEnabled: Bool = true
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Disabled-state bytter til textSoft i stedet for å redusere opasitet
    /// — ikonet forblir tydelig lesbart mot den translucente kapselen,
    /// og fargen alene signaliserer at handlingen ikke er tilgjengelig.
    private var iconColor: Color {
        guard isEnabled else { return Color.Trakke.textSoft }
        switch role {
        case .neutral: return Color.Trakke.brand
        case .destructive, .recording: return Color.Trakke.red
        case .primary: return Color.Trakke.brand
        }
    }
}

/// Liten pulsende indikator for opptaksstatus.
struct MapActionRecordingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.Trakke.red)
            .frame(width: 8, height: 8)
            .opacity(reduceMotion ? 1 : (isPulsing ? 0.3 : 1))
            .frame(width: 32, height: 44)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .accessibilityLabel(String(localized: "activity.recording"))
    }
}
