import SwiftUI

struct MeasurementToolbar: View {
    let mode: MeasurementMode
    let formattedResult: String?
    let hasPoints: Bool
    var onCancel: () -> Void
    var onUndo: () -> Void
    var onClear: () -> Void
    var onSelectMode: (MeasurementMode) -> Void

    // Fixed point sizes scaled with Dynamic Type via @ScaledMetric.
    @ScaledMetric(relativeTo: .subheadline) private var resultSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var hintSize: CGFloat = 13

    var body: some View {
        MapActionBar(position: .top) {
            ModeSegmentedToggle(selectedMode: mode, onSelect: onSelectMode)

            MapActionDivider()

            valueOrHint
                .padding(.horizontal, .Trakke.sm)
                .frame(maxWidth: .infinity, minHeight: 44)

            MapActionDivider()
            MapActionButton(
                systemImage: "xmark",
                role: .destructive,
                accessibilityLabel: String(localized: "common.cancel"),
                action: onCancel
            )
            MapActionDivider()
            MapActionButton(
                systemImage: "arrow.uturn.backward",
                isEnabled: hasPoints,
                accessibilityLabel: String(localized: "route.undo"),
                action: onUndo
            )
            MapActionDivider()
            MapActionButton(
                systemImage: "trash",
                isEnabled: hasPoints,
                accessibilityLabel: String(localized: "measurement.clear"),
                action: onClear
            )
        }
    }

    @ViewBuilder
    private var valueOrHint: some View {
        if let result = formattedResult {
            Text(result)
                .font(.system(size: resultSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.Trakke.text)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel(result)
        } else {
            Text(
                mode == .distance
                    ? String(localized: "measurement.distanceHint")
                    : String(localized: "measurement.areaHint")
            )
            .font(.system(size: hintSize))
            .foregroundStyle(Color.Trakke.textSoft)
            .lineLimit(1)
            // Minst 0.85 så hint-tekstene ikke kan skrumpe så mye at den ene
            // blir merkbart mindre enn den andre. Begge tekstene er korte nok
            // til at scaling vanligvis ikke trigger.
            .minimumScaleFactor(0.85)
        }
    }
}

private struct ModeSegmentedToggle: View {
    let selectedMode: MeasurementMode
    let onSelect: (MeasurementMode) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            modeButton(
                .distance,
                systemImage: "ruler",
                label: String(localized: "measurement.distance")
            )
            modeButton(
                .area,
                systemImage: "square.dashed",
                label: String(localized: "measurement.area")
            )
        }
        .padding(.leading, .Trakke.xs)
        .accessibilityElement(children: .contain)
    }

    private func modeButton(
        _ mode: MeasurementMode,
        systemImage: String,
        label: String
    ) -> some View {
        let isActive = mode == selectedMode
        return Button {
            guard mode != selectedMode else { return }
            HapticFeedback.tap()
            onSelect(mode)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? Color.Trakke.brand : Color.Trakke.textTertiary)
                .frame(width: 36, height: 32)
                .background {
                    if isActive {
                        Capsule().fill(Color.Trakke.brandTint)
                    }
                }
                // Hele 44×44-flaten er trykkbar, ikke bare den 36×32 visuelle
                // kapselen — contentShape ligger utenpå 44pt-rammen.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
