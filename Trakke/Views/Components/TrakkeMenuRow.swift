import SwiftUI

/// Standard menyvalg-rad brukt på tvers av alle sheets – én konsekvent stil
/// for handlinger, utvidelsesbokser, navigasjonslinjer og info-visninger.
/// Sørger for enhetlig høyde, padding, fontstørrelse og fargebruk.
struct TrakkeMenuRow<Trailing: View>: View {
    var icon: String? = nil
    let label: String
    var subtitle: String? = nil
    /// Bruk når subtitle er numerisk og må linjeres opp vertikalt – f.eks.
    /// koordinat-eksempler. Standard `Font.Trakke.captionSoft` brukes ellers.
    var subtitleFont: Font? = nil
    var iconColor: Color = Color.Trakke.brandLight
    var labelColor: Color = Color.Trakke.text
    var action: (() -> Void)? = nil
    /// Tilleggsverdi som VoiceOver skal lese – typisk innholdet i et trailing
    /// `TrakkeMenuRowValue`. Settes når trailing-visningen alene ikke er
    /// dekkende for accessibility.
    var accessibilityValue: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText)
        } else {
            content
                .accessibilityLabel(accessibilityText)
        }
    }

    private var content: some View {
        HStack(spacing: .Trakke.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(labelColor)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(subtitleFont ?? Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.vertical, 12)
        .frame(minHeight: .Trakke.touchMin)
        .contentShape(Rectangle())
    }

    private var accessibilityText: String {
        var parts: [String] = [label]
        if let subtitle, !subtitle.isEmpty { parts.append(subtitle) }
        if let accessibilityValue, !accessibilityValue.isEmpty { parts.append(accessibilityValue) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Trailing-glyph helpers

extension TrakkeMenuRow where Trailing == TrakkeMenuRowChevron {
    init(
        icon: String? = nil,
        label: String,
        subtitle: String? = nil,
        iconColor: Color = Color.Trakke.brandLight,
        labelColor: Color = Color.Trakke.text,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.labelColor = labelColor
        self.action = action
        self.trailing = { TrakkeMenuRowChevron() }
    }
}

extension TrakkeMenuRow where Trailing == EmptyView {
    init(
        icon: String? = nil,
        label: String,
        subtitle: String? = nil,
        iconColor: Color = Color.Trakke.brand,
        labelColor: Color = Color.Trakke.text
    ) {
        self.icon = icon
        self.label = label
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.labelColor = labelColor
        self.action = nil
        self.trailing = { EmptyView() }
    }
}

/// Standard chevron til høyre i menyrader – samme stil overalt.
struct TrakkeMenuRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(Font.Trakke.captionSoft.weight(.semibold))
            .foregroundStyle(Color.Trakke.textSoft)
            .accessibilityHidden(true)
    }
}

/// Ekstern-lenke-pil til høyre – markerer at trykket åpner Safari/eksternt.
struct TrakkeMenuRowExternal: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(Font.Trakke.captionSoft.weight(.semibold))
            .foregroundStyle(Color.Trakke.textSoft)
            .accessibilityHidden(true)
    }
}

/// Høyrejustert verdi til en menyrad – versjon, navn, statisk innstilling.
/// Bruk sammen med `accessibilityValue` på TrakkeMenuRow for å sikre at
/// VoiceOver leser verdien.
struct TrakkeMenuRowValue: View {
    let value: String

    var body: some View {
        Text(value)
            .font(Font.Trakke.bodyRegular)
            .foregroundStyle(Color.Trakke.textSoft)
            .accessibilityHidden(true)
    }
}

/// Checkmark-affordans for radio-/valg-rader. Vises kun når valgt.
/// Plassholdes ikke i ikke-valgt tilstand – Spacer i parent håndterer
/// høyrejustering uavhengig av om checkmark er der.
struct TrakkeMenuRowCheckmark: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Trakke.brandLight)
                .accessibilityHidden(true)
        }
    }
}
