import SwiftUI

/// Nav-HUD — én sammenhengende horisontal pille på toppen av skjermen.
/// Viser kompasspeiling, avstand til destinasjon, pause/stopp-kontroller
/// og kamera-veksler.
struct NavigationOverlayView: View {
    let navigationVM: NavigationViewModel
    let userHeading: Double?
    var onStop: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: .Trakke.sm) {
            compassNavBar
                .padding(.horizontal, .Trakke.lg)
                .padding(.top, .Trakke.sm)

            gpsIndicator
                .padding(.horizontal, .Trakke.lg)

            Spacer()

            if navigationVM.hasArrived {
                arrivalBanner
                    .onAppear {
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: String(localized: "navigation.arrived")
                        )
                    }
            }
        }
        .safeAreaPadding(.bottom)
        // Hindrer at HUD-en vokser seg over kartet ved svært store tekststørrelser.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: - Kompass-bar

    private var compassNavBar: some View {
        HStack(spacing: 0) {
            pauseResumeButton

            navBarDivider
            compassDirectionCell

            navBarDivider
            navBarStat(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                value: formatDistance(navigationVM.compassDistance)
            )

            navBarDivider
            stopButton
        }
        .background(Color.Trakke.surface.opacity(0.92))
        .clipShape(Capsule())
        .trakkeControlShadow()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Bar-celler

    private var pauseResumeButton: some View {
        Button {
            if navigationVM.isPaused {
                navigationVM.resumeNavigation()
            } else {
                navigationVM.pauseNavigation()
            }
        } label: {
            Image(systemName: navigationVM.isPaused ? "play.fill" : "pause.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Color.Trakke.brand)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(
            navigationVM.isPaused
                ? String(localized: "navigation.resume")
                : String(localized: "navigation.pause")
        )
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Color.Trakke.red)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "navigation.stopNavigation"))
    }

    private var compassDirectionCell: some View {
        let relativeBearing = computeRelativeBearing()
        return HStack(spacing: .Trakke.xs) {
            Image(systemName: "location.north.fill")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Color.Trakke.brand)
                .rotationEffect(.degrees(relativeBearing))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.5),
                    value: relativeBearing
                )
            Text(bearingText(navigationVM.compassBearing))
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.Trakke.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, .Trakke.sm)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "navigation.bearing")
                + ": \(Int(navigationVM.compassBearing))\u{00B0}"
        )
    }

    private func navBarStat(icon: String, value: String) -> some View {
        HStack(spacing: .Trakke.xs) {
            Image(systemName: icon)
                .font(.system(.caption, weight: .regular))
                .foregroundStyle(Color.Trakke.textSoft)
            Text(value)
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.Trakke.text)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, .Trakke.sm)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(value)
    }

    private var navBarDivider: some View {
        Rectangle()
            .fill(Color.Trakke.border)
            .frame(width: 1, height: 24)
    }

    // MARK: - GPS-indikator

    @ViewBuilder
    private var gpsIndicator: some View {
        switch navigationVM.gpsQuality {
        case .good:
            EmptyView()
        case .reduced:
            gpsPill(icon: "antenna.radiowaves.left.and.right.slash", color: Color.Trakke.yellow)
        case .lost:
            gpsPill(icon: "location.slash", color: Color.Trakke.red)
        }
    }

    private func gpsPill(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, .Trakke.md)
            .padding(.vertical, .Trakke.xs)
            .background(Color.Trakke.surface.opacity(0.92))
            .clipShape(Capsule())
            .trakkeControlShadow()
            .accessibilityLabel(
                navigationVM.gpsQuality == .lost
                    ? String(localized: "navigation.gpsLost")
                    : String(localized: "navigation.gpsReduced")
            )
    }

    // MARK: - Ankomst-banner

    private var arrivalBanner: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "flag.checkered")
                .font(.system(.callout, weight: .semibold))
            Text(String(localized: "navigation.arrived"))
                .font(Font.Trakke.bodyMedium)
        }
        .foregroundStyle(Color.Trakke.textInverse)
        .padding(.horizontal, .Trakke.lg)
        .padding(.vertical, .Trakke.sm)
        .background(Color.Trakke.mapNavLine)
        .clipShape(Capsule())
        .padding(.bottom, .Trakke.sm)
    }

    // MARK: - Helpers

    private func formatDistance(_ meters: Double) -> String {
        MeasurementService.formatDistance(meters)
    }

    private func computeRelativeBearing() -> Double {
        let heading = userHeading ?? 0
        var delta = navigationVM.compassBearing - heading
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    private func bearingText(_ degrees: Double) -> String {
        let n = ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let direction: String
        switch n {
        case 337.5..<360, 0..<22.5: direction = "N"
        case 22.5..<67.5: direction = "N\u{00D8}"
        case 67.5..<112.5: direction = "\u{00D8}"
        case 112.5..<157.5: direction = "S\u{00D8}"
        case 157.5..<202.5: direction = "S"
        case 202.5..<247.5: direction = "SV"
        case 247.5..<292.5: direction = "V"
        case 292.5..<337.5: direction = "NV"
        default: direction = ""
        }
        return "\(Int(n))\u{00B0} \(direction)"
    }
}
