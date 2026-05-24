import SwiftUI

/// Nav-HUD — én sammenhengende horisontal pille på toppen av skjermen,
/// inspirert av HiiKER men i Tråkkes egne tokens. Ingen tekstlabels, bare
/// ikoner og verdier. Ingen knapper i bunnen — pause og avslutt er
/// integrert som ikon-knapper i samme pille.
struct NavigationOverlayView: View {
    let navigationVM: NavigationViewModel
    let userHeading: Double?
    let isConnected: Bool
    var onStop: () -> Void
    var onSwitchToCompass: () -> Void
    var onSwitchToRoute: () -> Void
    var onToggleCamera: () -> Void
    var onReroute: () -> Void
    var onSearchTapped: () -> Void
    var onCategoryTapped: () -> Void
    var onEmergencyTapped: () -> Void
    var onWeatherTapped: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showMoreMenu = false

    var body: some View {
        VStack(spacing: .Trakke.sm) {
            // MARK: - Topp: sving-instruks-pille (når aktiv)
            if case .route = navigationVM.mode,
               let instruction = navigationVM.nextInstruction,
               !navigationVM.isPaused {
                turnInstructionPill(instruction)
                    .padding(.horizontal, .Trakke.lg)
            }

            // MARK: - Topp: HiiKER-stil sammenhengende bar
            topNavBar
                .padding(.horizontal, .Trakke.lg)
                .padding(.top, .Trakke.sm)

            // MARK: - Sentralt: off-track + GPS + ankomst
            if navigationVM.isOffTrack {
                DeviationChipView(
                    distance: navigationVM.offTrackDistance,
                    canReroute: navigationVM.canReroute && isConnected,
                    onReroute: onReroute,
                    onDismiss: { navigationVM.dismissDeviation() }
                )
                .padding(.horizontal, .Trakke.lg)
            }

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
    }

    // MARK: - Nav-bar (sammenhengende pille)

    @ViewBuilder
    private var topNavBar: some View {
        switch navigationVM.mode {
        case .route:
            routeNavBar
        case .compass:
            compassNavBar
        }
    }

    private var routeNavBar: some View {
        // Distanse vises alltid — bruker progress.distanceRemaining etter
        // første GPS-oppdatering, totalDistance som fallback like etter
        // start (eller for fulgte ruter som ennå ikke har snap-resultat).
        // Tid og høydemeter krever progress-data, så de vises bare når
        // tilgjengelig.
        let distanceValue = navigationVM.progress?.distanceRemaining ?? navigationVM.totalDistance

        return HStack(spacing: 0) {
            pauseResumeButton

            if let eta = navigationVM.progress?.estimatedTimeRemaining {
                navBarDivider
                navBarStat(icon: "clock", value: formatTime(eta))
            }

            if let gain = navigationVM.progress?.elevationGainRemaining, gain > 0 {
                navBarDivider
                navBarStat(icon: "arrow.up", value: "+\(Int(gain)) m")
            }

            navBarDivider
            navBarStat(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                value: formatDistance(distanceValue)
            )

            navBarDivider
            moreButton
            navBarDivider
            stopButton
        }
        .background(Color.Trakke.surface.opacity(0.92))
        .clipShape(Capsule())
        .trakkeControlShadow()
        .accessibilityElement(children: .contain)
        .trakkeDialog(
            isPresented: $showMoreMenu,
            buttons: moreMenuButtons
        )
    }

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
            moreButton
            navBarDivider
            stopButton
        }
        .background(Color.Trakke.surface.opacity(0.92))
        .clipShape(Capsule())
        .trakkeControlShadow()
        .accessibilityElement(children: .contain)
        .trakkeDialog(
            isPresented: $showMoreMenu,
            buttons: moreMenuButtons
        )
    }

    private var moreMenuButtons: [TrakkeDialogButton] {
        var buttons: [TrakkeDialogButton] = []

        switch navigationVM.mode {
        case .route:
            buttons.append(.primary(String(localized: "navigation.switchToCompass")) {
                onSwitchToCompass()
            })
        case .compass:
            buttons.append(.primary(String(localized: "navigation.switchToRoute")) {
                onSwitchToRoute()
            })
        }

        let cameraLabel: String = navigationVM.cameraMode == .northUp
            ? String(localized: "navigation.cameraMode.courseUp")
            : String(localized: "navigation.cameraMode.northUp")
        buttons.append(.primary(cameraLabel) {
            onToggleCamera()
        })

        buttons.append(.cancel())
        return buttons
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
                .font(.system(size: 15, weight: .semibold))
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.Trakke.red)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "navigation.stopNavigation"))
    }

    private var moreButton: some View {
        Button {
            showMoreMenu = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.Trakke.textSoft)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "navigation.more"))
    }

    private var compassDirectionCell: some View {
        let relativeBearing = computeRelativeBearing()
        return HStack(spacing: .Trakke.xs) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.Trakke.brand)
                .rotationEffect(.degrees(relativeBearing))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.5),
                    value: relativeBearing
                )
            Text(bearingText(navigationVM.compassBearing))
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
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
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.Trakke.textSoft)
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
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

    // MARK: - Sving-instruks-pille

    private func turnInstructionPill(_ instruction: TurnInstruction) -> some View {
        let distToTurn: Double? = {
            guard let progress = navigationVM.progress else { return nil }
            let d = instruction.distance - (progress.totalDistance - progress.distanceRemaining)
            return d > 0 ? d : nil
        }()
        let isImminent = (distToTurn ?? .infinity) < 100

        return HStack(spacing: .Trakke.md) {
            Image(systemName: turnIcon(instruction.type))
                .font(isImminent ? .title3.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(isImminent ? Color.Trakke.textInverse : Color.Trakke.brand)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(instruction.text)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(isImminent ? Color.Trakke.textInverse : Color.Trakke.text)
                    .lineLimit(2)
                if let distToTurn {
                    Text(formatDistance(distToTurn))
                        .font(
                            isImminent
                                ? Font.Trakke.bodyMedium.monospacedDigit()
                                : Font.Trakke.caption.monospacedDigit()
                        )
                        .foregroundStyle(
                            isImminent ? Color.Trakke.textInverse.opacity(0.9) : Color.Trakke.textSoft
                        )
                        .contentTransition(.numericText(countsDown: true))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.3),
                            value: Int(distToTurn / 5) * 5
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, .Trakke.cardPadH)
        .padding(.vertical, .Trakke.sm)
        .frame(minHeight: 56)
        .background(isImminent ? Color.Trakke.brand : Color.Trakke.surface.opacity(0.92))
        .clipShape(Capsule())
        .trakkeControlShadow()
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
            .font(.system(size: 14, weight: .semibold))
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

    // MARK: - Arrival-banner

    private var arrivalBanner: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 16, weight: .semibold))
            Text(String(localized: "navigation.arrived"))
                .font(Font.Trakke.bodyMedium)
        }
        .foregroundStyle(Color.Trakke.textInverse)
        .padding(.horizontal, .Trakke.lg)
        .padding(.vertical, .Trakke.sm)
        .background(Color.Trakke.brand)
        .clipShape(Capsule())
        .padding(.bottom, .Trakke.sm)
    }

    // MARK: - Helpers

    private func formatDistance(_ meters: Double) -> String {
        MeasurementService.formatDistance(meters)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)t \(minutes)m"
        }
        return "\(minutes)m"
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

    private func turnIcon(_ type: TurnType) -> String {
        switch type {
        case .straight: return "arrow.up"
        case .slightRight: return "arrow.up.right"
        case .right: return "arrow.turn.up.right"
        case .sharpRight: return "arrow.turn.down.right"
        case .slightLeft: return "arrow.up.left"
        case .left: return "arrow.turn.up.left"
        case .sharpLeft: return "arrow.turn.down.left"
        case .uTurn: return "arrow.uturn.down"
        case .destination: return "flag.fill"
        case .depart: return "figure.walk"
        case .ferry: return "ferry.fill"
        case .other: return "arrow.up"
        }
    }
}
